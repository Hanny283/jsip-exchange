open! Core
open! Async
open Jsip_types
open Jsip_order_book

(* A unit of work queued for the matching engine. Submits and cancels share a
   single ordered queue so the engine processes them strictly in arrival
   order, regardless of which client (or which RPC) produced them. *)
type command =
  | Submit of
      { participant : Participant.t
      ; request : Order.Request.t
      }
  | Cancel of
      { participant : Participant.t
      ; client_order_id : Client_order_id.t
      }

(* A command paired with the time its RPC handler was entered, so the
   matching loop can report the end-to-end latency (handler entry to engine
   completion) to the stats collector. *)
type queued_command =
  { command : command
  ; received_at : Time_ns.t
  }

type t =
  { engine : Matching_engine.t
  ; dispatcher : Dispatcher.t
  ; request_writer : queued_command Pipe.Writer.t
  ; tcp_server : (Socket.Address.Inet.t, int) Tcp.Server.t
  ; port : int
  ; publisher : Stats_publisher.t
  }

module Connection_state = struct
  type t = { mutable session : Session.t option }
end

(* Bound how many client commands can sit in the queue waiting for the
   matching engine. Once the queue is full, [Pipe.write] returns a pending
   deferred and the enqueueing RPC handler blocks until the engine has
   processed enough commands to free up space — clients get backpressure
   without the server's memory growing unboundedly. *)
let request_queue_size_budget = 1024

(* Both the submit and cancel RPCs are one-way: enqueue the command and
   return [Ok ()] immediately. The engine's response (an [Order_accept] /
   [Fill] / [Order_reject] for a submit, an [Order_cancel] / [Cancel_reject]
   for a cancel) is delivered asynchronously on the participant's session
   feed. *)
let enqueue ~request_writer command =
  let%map () = Pipe.write_if_open request_writer command in
  Ok ()
;;

let start_matching_loop ~engine ~dispatcher ~collector request_reader =
  don't_wait_for
    (Pipe.iter_without_pushback
       request_reader
       ~f:(fun { command; received_at } ->
         Stats_collector.record_loop_iteration
           collector
           ~now:(Time_ns.now ());
         let events =
           match command with
           | Submit { participant; request } ->
             Matching_engine.submit engine request ~participant
           | Cancel { participant; client_order_id } ->
             Matching_engine.cancel engine ~participant ~client_order_id
         in
         let latency = Time_ns.diff (Time_ns.now ()) received_at in
         (match command with
          | Submit _ ->
            Stats_collector.record_submit_latency collector latency
          | Cancel _ ->
            Stats_collector.record_cancel_latency collector latency);
         Dispatcher.dispatch dispatcher events))
;;

let handle_session_feed (state : Connection_state.t) =
  match state.session with
  | None -> Or_error.error_string "not logged in"
  | Some session -> Ok (Session.reader session)
;;

(* Stream a dispatcher feed [reader] to one subscriber with per-event
   pushback: [Pipe.iter] does not pull the next event until the current one
   has flushed to the subscriber, so a slow consumer backs up [reader] rather
   than the backlog disappearing into the transport's (effectively unbounded)
   send buffer. The dispatcher bounds and drops on [reader], so this backlog
   is capped and shows up in the pipe-occupancy pane. Closing either end
   tears down the other. Used for the market-data and audit firehoses, where
   a lossy feed for a slow observer is acceptable. *)
let forward_feed
  reader
  (writer : Exchange_event.t Rpc.Pipe_rpc.Direct_stream_writer.t)
  =
  don't_wait_for
    (let%map () = Rpc.Pipe_rpc.Direct_stream_writer.closed writer in
     Pipe.close_read reader);
  don't_wait_for
    (let%map () =
       Pipe.iter reader ~f:(fun event ->
         match Rpc.Pipe_rpc.Direct_stream_writer.write writer event with
         | `Closed ->
           Pipe.close_read reader;
           return ()
         | `Flushed flushed ->
           (* Give up waiting if the subscriber vanishes mid-flush, so a
              disconnect can't wedge the iteration. *)
           Deferred.any
             [ flushed; Rpc.Pipe_rpc.Direct_stream_writer.closed writer ])
     in
     Rpc.Pipe_rpc.Direct_stream_writer.close writer);
  return (Ok ())
;;

let start
  ~symbol_registry
  ~port
  ?(stats_interval = Time_ns.Span.second)
  ?(fundamental = fun _ -> None)
  ()
  =
  (* The registry is the authority on name<->id (the i-th symbol is id [i]);
     the server serves it over the directory RPC and otherwise works purely
     in ids — it never renders a name. *)
  let num_symbols = Symbol_registry.num_symbols symbol_registry in
  let engine = Matching_engine.create ~num_symbols in
  (* One registry shared by everything that touches participant ids: the
     dispatcher (interns at login, routes by id) and the stats publisher
     (resolves flushed rows back to names). A fill names two participants, so
     an id has to mean the same thing to every component. *)
  let registry = Participant_id.Registry.create () in
  let dispatcher = Dispatcher.create ~registry ~num_symbols in
  let request_reader, request_writer = Pipe.create () in
  Pipe.set_size_budget request_writer request_queue_size_budget;
  let collector = Stats_collector.create () in
  let publisher =
    Stats_publisher.create
      ~collector
      ~dispatcher
      ~registry
      ~engine
      ~num_symbols
      ~request_queue_length:(fun () -> Pipe.length request_writer)
      ~fundamental
  in
  start_matching_loop ~engine ~dispatcher ~collector request_reader;
  let implementations =
    Rpc.Implementations.create_exn
      ~implementations:
        [ Rpc.Rpc.implement
            Rpc_protocol.submit_order_rpc
            (fun (state : Connection_state.t) request ->
               let received_at = Time_ns.now () in
               match state.session with
               | None ->
                 Deferred.return (Or_error.error_string "not logged in")
               | Some session ->
                 (* Identity comes from the login, not the request — the wire
                    request carries no participant at all, so a client can't
                    submit on behalf of someone else. *)
                 let participant = Session.participant session in
                 (* Stats key by the interned id; the engine command keeps
                    the name (the engine is out of the id's scope). Both come
                    straight off the session — no registry lookup. *)
                 Stats_collector.incr_orders_submitted
                   collector
                   (Session.participant_id session);
                 enqueue
                   ~request_writer
                   { command = Submit { participant; request }; received_at })
        ; Rpc.Rpc.implement'
            Rpc_protocol.book_query_rpc
            (fun _state symbol ->
               Matching_engine.book engine symbol
               |> Option.map ~f:Order_book.snapshot)
        ; Rpc.Pipe_rpc.implement_direct
            Rpc_protocol.market_data_rpc
            (fun _state symbols writer ->
               (* Ids arrive off the wire unvalidated; refuse the whole
                  subscription rather than silently serving an empty feed for
                  a symbol this exchange does not trade. *)
               match
                 List.find symbols ~f:(fun id ->
                   Symbol_id.to_int id >= num_symbols)
               with
               | Some id ->
                 return
                   (Error
                      (Error.create_s
                         [%message "unknown symbol id" (id : Symbol_id.t)]))
               | None ->
                 forward_feed
                   (Dispatcher.subscribe_market_data dispatcher symbols)
                   writer)
        ; Rpc.Pipe_rpc.implement_direct
            Rpc_protocol.audit_log_rpc
            (fun _state () writer ->
               forward_feed (Dispatcher.subscribe_audit dispatcher) writer)
        ; Rpc.Pipe_rpc.implement
            Rpc_protocol.exchange_stats_rpc
            (fun _state () ->
               return (Ok (Stats_publisher.subscribe publisher)))
        ; Rpc.Rpc.implement'
            Rpc_protocol.symbol_directory_rpc
            (fun _state () -> Symbol_registry.to_directory symbol_registry)
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
               let received_at = Time_ns.now () in
               match state.session with
               | None ->
                 Deferred.return (Or_error.error_string "not logged in")
               | Some session ->
                 let participant = Session.participant session in
                 Stats_collector.incr_cancels_submitted
                   collector
                   (Session.participant_id session);
                 enqueue
                   ~request_writer
                   { command = Cancel { participant; client_order_id }
                   ; received_at
                   })
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
  Stats_publisher.start
    publisher
    ~interval:stats_interval
    ~stop:(Tcp.Server.close_finished tcp_server);
  { engine
  ; dispatcher
  ; request_writer
  ; tcp_server
  ; port = actual_port
  ; publisher
  }
;;

let port t = t.port

let close t =
  Pipe.close t.request_writer;
  Tcp.Server.close t.tcp_server
;;

let close_finished t = Tcp.Server.close_finished t.tcp_server

module For_testing = struct
  let publish_stats_snapshot t = Stats_publisher.tick t.publisher
end
