open! Core
open! Async
open Jsip_gateway
open Jsip_types

let with_server ~symbols ?stats_interval f =
  (* Tests keep passing a plain name list; the registry (the id authority) is
     built here — one churn point instead of one per test. *)
  let symbol_registry = Symbol_registry.of_symbols symbols in
  let%bind server =
    Exchange_server.start ~symbol_registry ~port:0 ?stats_interval ()
  in
  let port = Exchange_server.port server in
  Monitor.protect
    (fun () -> f ~server ~port)
    ~finally:(fun () -> Exchange_server.close server)
;;

type client = { conn : Rpc.Connection.t }

let connect_as ~port participant =
  let where =
    Tcp.Where_to_connect.of_host_and_port { host = "localhost"; port }
  in
  let%bind conn = Rpc.Connection.client where >>| Result.ok_exn in
  let%bind (_ : Participant.t) =
    Rpc.Rpc.dispatch_exn
      Rpc_protocol.login_rpc
      conn
      (Participant.to_string participant)
    >>| ok_exn
  in
  (* Fetch the directory once at connect — the same dance a real client does
     — so this feed prints human symbol names, not raw ids. *)
  let%bind symbols =
    Rpc.Rpc.dispatch_exn Rpc_protocol.symbol_directory_rpc conn ()
    >>| Symbol_registry.of_directory
    >>| ok_exn
  in
  let%bind session_feed, _metadata =
    Rpc.Pipe_rpc.dispatch_exn Rpc_protocol.session_feed_rpc conn ()
  in
  don't_wait_for
    (Pipe.iter_without_pushback session_feed ~f:(fun event ->
       let e = Protocol.format_event ~symbols event in
       print_endline [%string "[%{participant#Participant}] %{e}"]));
  Deferred.return { conn }
;;

let connect_raw ~port =
  let where =
    Tcp.Where_to_connect.of_host_and_port { host = "localhost"; port }
  in
  Rpc.Connection.client where >>| Result.ok_exn
;;

let connection client = client.conn

let rpc_submit client request =
  Rpc.Rpc.dispatch_exn Rpc_protocol.submit_order_rpc client.conn request
  >>| ok_exn
;;

let rpc_book client symbol =
  Rpc.Rpc.dispatch_exn Rpc_protocol.book_query_rpc client.conn symbol
;;

let subscribe_stats client =
  let%map stats_feed, _metadata =
    Rpc.Pipe_rpc.dispatch_exn Rpc_protocol.exchange_stats_rpc client.conn ()
  in
  stats_feed
;;
