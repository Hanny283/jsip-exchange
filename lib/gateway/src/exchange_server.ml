open! Core
open! Async
open Jsip_types
open Jsip_order_book

(* A unit of work queued for the matching engine. Submits and cancels share a
   single ordered queue so the engine processes them strictly in arrival
   order, regardless of which client (or which RPC) produced them. *)
type command =
  | Submit of Order.Request.t
  | Cancel of
      { participant : Participant.t
      ; client_order_id : Client_order_id.t
      }

type t =
  { engine : Matching_engine.t
  ; dispatcher : Dispatcher.t
  ; request_writer : command Pipe.Writer.t
  ; tcp_server : (Socket.Address.Inet.t, int) Tcp.Server.t
  ; port : int
  }

module Connection_state = struct
  type t = { mutable session : Session.t option }

  let participant t = Option.map t.session ~f:Session.participant
end

(* Bound how many client commands can sit in the queue waiting for the
   matching engine. Once the queue is full, [Pipe.write] returns a pending
   deferred and the enqueueing RPC handler blocks until the engine has
   processed enough commands to free up space — clients get backpressure
   without the server's memory growing unboundedly. *)
let request_queue_size_budget = 1024

(* Both the submit and cancel RPCs are one-way: enqueue the command and return
   [Ok ()] immediately. The engine's response (an [Order_accept] / [Fill] /
   [Order_reject] for a submit, an [Order_cancel] / [Cancel_reject] for a
   cancel) is delivered asynchronously on the participant's session feed. *)
let enqueue ~request_writer command =
  let%map () = Pipe.write_if_open request_writer command in
  Ok ()
;;

let start_matching_loop ~engine ~dispatcher request_reader =
  don't_wait_for
    (Pipe.iter_without_pushback request_reader ~f:(fun command ->
       let events =
         match command with
         | Submit request -> Matching_engine.submit engine request
         | Cancel { participant; client_order_id } ->
           Matching_engine.cancel engine ~participant ~client_order_id
       in
       Dispatcher.dispatch dispatcher events))
;;

let handle_session_feed (state : Connection_state.t) =
  match state.session with
  | None -> Or_error.error_string "not logged in"
  | Some session -> Ok (Session.reader session)
;;

let start ~symbols ~port () =
  let engine = Matching_engine.create symbols in
  let dispatcher = Dispatcher.create () in
  let request_reader, request_writer = Pipe.create () in
  Pipe.set_size_budget request_writer request_queue_size_budget;
  start_matching_loop ~engine ~dispatcher request_reader;
  let implementations =
    Rpc.Implementations.create_exn
      ~implementations:
        [ Rpc.Rpc.implement
            Rpc_protocol.submit_order_rpc
            (fun (state : Connection_state.t) request ->
               match state.session with
               | None ->
                 Deferred.return (Or_error.error_string "not logged in")
               | Some session ->
                 (* Identity comes from the login, not the request, so a
                    logged-in client can't submit on behalf of someone
                    else. *)
                 let participant = Session.participant session in
                 let (rq : Order.Request.t) = { request with participant } in
                 enqueue ~request_writer (Submit rq))
        ; Rpc.Rpc.implement' Rpc_protocol.book_query_rpc (fun _state symbol ->
            Matching_engine.book engine symbol
            |> Option.map ~f:Order_book.snapshot)
        ; Rpc.Pipe_rpc.implement
            Rpc_protocol.market_data_rpc
            (fun _state symbols ->
               let reader =
                 Dispatcher.subscribe_market_data dispatcher symbols
               in
               return (Ok reader))
        ; Rpc.Pipe_rpc.implement Rpc_protocol.audit_log_rpc (fun _state () ->
            let reader = Dispatcher.subscribe_audit dispatcher in
            return (Ok reader))
        ; Rpc.Rpc.implement
            Rpc_protocol.login_rpc
            (fun (state : Connection_state.t) participant_name ->
               let stripped =
                 String.filter participant_name ~f:(fun char ->
                   not (Char.is_whitespace char))
               in
               if String.is_empty stripped
               then
                 Deferred.return
                   (Or_error.error_string
                      "invalid name: empty or all whitespace")
               else (
                 let participant = Participant.of_string participant_name in
                 match Dispatcher.find_session dispatcher participant with
                 | Some existing when not (Session.is_closed existing) ->
                   (* Name is already held by a live connection. Reject the
                      newcomer and leave the incumbent's feed untouched. *)
                   Deferred.return
                     (Or_error.error_string
                        [%string
                          "already logged in as %{participant#Participant}"])
                 | _ ->
                   let%bind () =
                     Dispatcher.set_up_session dispatcher participant
                   in
                   let session =
                     Option.value_exn
                       (Dispatcher.find_session dispatcher participant)
                   in
                   state.session <- Some session;
                   Deferred.return (Ok participant)))
        ; Rpc.Pipe_rpc.implement
            Rpc_protocol.session_feed_rpc
            (fun (state : Connection_state.t) () ->
               Deferred.return (handle_session_feed state))
        ; Rpc.Rpc.implement
            Rpc_protocol.cancel_order_rpc
            (fun (state : Connection_state.t) client_order_id ->
               match Connection_state.participant state with
               | None ->
                 Deferred.return (Or_error.error_string "not logged in")
               | Some participant ->
                 enqueue
                   ~request_writer
                   (Cancel { participant; client_order_id }))
        ]
      ~on_unknown_rpc:`Close_connection
      ~on_exception:Log_on_background_exn
  in
  let%map tcp_server =
    Rpc.Connection.serve
      ~implementations
      ~initial_connection_state:(fun _addr conn : Connection_state.t ->
        let (state : Connection_state.t) = { session = None } in
        don't_wait_for
          (let%bind () = Rpc.Connection.close_finished conn in
           match state.session with
           | None -> Deferred.return ()
           | Some session -> Dispatcher.clean_up_session dispatcher session);
        state)
      ~where_to_listen:(Tcp.Where_to_listen.of_port port)
      ()
  in
  let actual_port = Tcp.Server.listening_on tcp_server in
  { engine; dispatcher; request_writer; tcp_server; port = actual_port }
;;

let port t = t.port

let close t =
  Pipe.close t.request_writer;
  Tcp.Server.close t.tcp_server
;;

let close_finished t = Tcp.Server.close_finished t.tcp_server
