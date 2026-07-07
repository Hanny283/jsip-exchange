open! Core
open! Async
open Jsip_gateway

let retry_delay = Time_ns.Span.of_sec 1.

(* Subscribe to the stats pipe on an established connection and drain it
   until it closes. Returns once the subscription is over, successful or not;
   [run] decides when to try again. *)
let drain_stats connection ~on_sample =
  match%bind
    Rpc.Pipe_rpc.dispatch Rpc_protocol.exchange_stats_rpc connection ()
  with
  | Error err | Ok (Error err) ->
    Log.Global.error_s
      [%message "exchange-stats subscription failed" (err : Error.t)];
    return ()
  | Ok (Ok (pipe, (_ : Rpc.Pipe_rpc.Metadata.t))) ->
    let%map () = Pipe.iter_without_pushback pipe ~f:on_sample in
    Log.Global.error_s
      [%message "exchange-stats pipe closed; will reconnect"]
;;

let rec run ~host ~port ~on_sample =
  let%bind () =
    match%bind
      Rpc.Connection.client
        (Tcp.Where_to_connect.of_host_and_port { host; port })
    with
    | Error exn ->
      Log.Global.error_s
        [%message
          "failed to connect to exchange"
            (host : string)
            (port : int)
            (exn : Exn.t)];
      return ()
    | Ok connection ->
      let%bind () = drain_stats connection ~on_sample in
      Rpc.Connection.close connection
  in
  let%bind () = Clock_ns.after retry_delay in
  run ~host ~port ~on_sample
;;
