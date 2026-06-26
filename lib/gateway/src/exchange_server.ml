open! Core
open! Async
open Jsip_types
open Jsip_order_book

type t =
  { engine : Matching_engine.t
  ; dispatcher : Dispatcher.t
  ; request_writer : Order.Request.t Pipe.Writer.t
  ; tcp_server : (Socket.Address.Inet.t, int) Tcp.Server.t
  ; port : int
  }

module Connection_state = struct
  type t = { mutable session : Session.t option }

  let participant t = Option.map t.session ~f:Session.participant
end

(* Bound how many client requests can sit in the queue waiting for the
   matching engine. Once the queue is full, [Pipe.write] returns a pending
   deferred and the [submit_order_rpc] handler blocks until the engine has
   processed enough requests to free up space — clients get backpressure
   without the server's memory growing unboundedly. *)
let request_queue_size_budget = 1024

let handle_submit ~request_writer (request : Order.Request.t) =
  let%map () = Pipe.write_if_open request_writer request in
  Ok ()
;;

let get_order dispatcher participant client_order_id =
  let participant_state_table = Dispatcher.state_table dispatcher in
  let participant_state =
    Hashtbl.find_exn participant_state_table participant
  in
  Participant_state.get_order participant_state client_order_id
;;

let handle_cancel_order
  ~(event_writer : Exchange_event.t Pipe.Writer.t)
  (dispatcher : Dispatcher.t)
  (participant : Participant.t)
  (book : Order_book.t)
  (client_order_id : Client_order_id.t)
  =
  let participant_state_table = Dispatcher.state_table dispatcher in
  let participant_state =
    Hashtbl.find_exn participant_state_table participant
  in
  let order =
    Participant_state.get_order participant_state client_order_id
  in
  match order with
  | Some order ->
    Participant_state.remove_order participant_state client_order_id;
    Order_book.remove book (Order.order_id order);
    let (event : Exchange_event.t) =
      Order_cancel
        { order_id = Order.order_id order
        ; participant = Order.participant order
        ; symbol = Order.symbol order
        ; remaining_size = Order.size order
        ; reason = Participant_requested
        ; client_order_id = Order.client_order_id order
        }
    in
    Dispatcher.dispatch dispatcher [ event ];
    let%map () = Pipe.write_if_open event_writer event in
    Option.iter
      (Order_book.best_price book (Order.side order))
      ~f:(fun best_price ->
        if Price.to_int_cents best_price
           = Price.to_int_cents (Order.price order)
        then
          Dispatcher.dispatch
            dispatcher
            [ Best_bid_offer_update
                { symbol = Order.symbol order
                ; bbo = Order_book.best_bid_offer book
                }
            ]
        else ())
  | None ->
    let (event : Exchange_event.t) =
      Cancel_reject
        { participant; client_order_id; reason = "Already filled" }
    in
    Dispatcher.dispatch dispatcher [ event ];
    let%map () = Pipe.write_if_open event_writer event in
    ()
;;

let handle_session_feed (state : Connection_state.t) =
  match state.session with
  | None -> Error.raise (Error.of_string "not logged in ")
  | Some session -> Ok (Session.reader session)
;;

let start_matching_loop ~engine ~dispatcher request_reader =
  don't_wait_for
    (Pipe.iter_without_pushback request_reader ~f:(fun request ->
       let events = Matching_engine.submit engine request in
       let _ =
         match events with
         | Order_accept { order_id; request } :: _ ->
           let participant_state =
             Hashtbl.find
               (Dispatcher.state_table dispatcher)
               request.participant
           in
           (match participant_state with
            | Some participant_state ->
              Participant_state.push_to_client_orders
                participant_state
                request.client_order_id
                (Order.create request ~order_id)
            | None -> ())
         | _ -> ()
       in
       Dispatcher.dispatch dispatcher events))
;;

let start ~symbols ~port () =
  let engine = Matching_engine.create symbols in
  let book = Matching_engine.book engine in
  let dispatcher = Dispatcher.create () in
  let event_reader, event_writer = Pipe.create () in
  let request_reader, request_writer = Pipe.create () in
  Pipe.set_size_budget request_writer request_queue_size_budget;
  start_matching_loop ~engine ~dispatcher request_reader;
  let implementations =
    Rpc.Implementations.create_exn
      ~implementations:
        [ Rpc.Rpc.implement
            Rpc_protocol.submit_order_rpc
            (fun (state : Connection_state.t) request ->
               let session = state.session in
               match session with
               | None -> Error.raise (Error.of_string "not logged in")
               | Some session ->
                 let participant = Session.participant session in
                 let (rq : Order.Request.t) =
                   { symbol = request.symbol
                   ; participant
                   ; side = request.side
                   ; price = request.price
                   ; size = request.size
                   ; time_in_force = request.time_in_force
                   ; client_order_id = request.client_order_id
                   }
                 in
                 let participant_state_table =
                   Dispatcher.state_table dispatcher
                 in
                 let participant_state =
                   Hashtbl.find_exn participant_state_table participant
                 in
                 let client_order_to_order_table =
                   Participant_state.client_orders participant_state
                 in
                 if Hashtbl.mem
                      client_order_to_order_table
                      rq.client_order_id
                 then (
                   Dispatcher.dispatch
                     dispatcher
                     [ Order_reject
                         { request = rq
                         ; reason = "Duplicate Client_order_id"
                         }
                     ];
                   Deferred.Or_error.ok_unit)
                 else handle_submit ~request_writer rq)
        ; Rpc.Rpc.implement' Rpc_protocol.book_query_rpc (fun state symbol ->
            ignore state;
            Matching_engine.book engine symbol
            |> Option.map ~f:Order_book.snapshot)
        ; Rpc.Pipe_rpc.implement
            Rpc_protocol.market_data_rpc
            (fun state symbols ->
               ignore state;
               let reader =
                 Dispatcher.subscribe_market_data dispatcher symbols
               in
               return (Ok reader))
        ; Rpc.Pipe_rpc.implement Rpc_protocol.audit_log_rpc (fun state () ->
            ignore state;
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
                 Error.raise
                   (Error.of_string "Invalid Name: Empty or All whitespaces")
               else (
                 let participant = Participant.of_string participant_name in
                 let session = Session.create participant in
                 state.session <- Some session;
                 let%bind () =
                   Dispatcher.set_up_session dispatcher participant
                 in
                 Deferred.return (Ok participant)))
        ; Rpc.Pipe_rpc.implement
            Rpc_protocol.session_feed_rpc
            (fun (state : Connection_state.t) () ->
               Deferred.return (handle_session_feed state))
        ; Rpc.Rpc.implement
            Rpc_protocol.cancel_order_rpc
            (fun (state : Connection_state.t) client_order_id ->
               let participant = Connection_state.participant state in
               let order =
                 match participant with
                 | Some participant ->
                   get_order dispatcher participant client_order_id
                 | None -> None
               in
               let symbol =
                 match order with
                 | Some order -> Some (Order.symbol order)
                 | None -> None
               in
               let order_book =
                 match symbol with
                 | Some symbol -> Matching_engine.book engine symbol
                 | None -> None
               in
               match order_book, participant with
               | Some order_book, Some participant ->
                 let%bind () =
                   handle_cancel_order
                     ~event_writer
                     dispatcher
                     participant
                     order_book
                     client_order_id
                 in
                 Deferred.Or_error.ok_unit
               | _, _ ->
                 Deferred.return
                   (Error0
                      (Error.of_string
                         "Cancel failed: no related order or participant")))
        ]
      ~on_unknown_rpc:`Close_connection
      ~on_exception:Log_on_background_exn
  in
  let%map tcp_server =
    Rpc.Connection.serve
      ~implementations
      ~initial_connection_state:(fun _addr _conn : Connection_state.t ->
        let (state : Connection_state.t) = { session = None } in
        don't_wait_for
          (let%bind () = Rpc.Connection.close_finished _conn in
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
