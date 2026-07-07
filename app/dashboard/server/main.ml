(** [jsip-dashboard]: the native bridge between an exchange server and the
    browser dashboard.

    It tails {!Jsip_gateway.Rpc_protocol.exchange_stats_rpc} into a bounded
    {!Jsip_dashboard_server.Sample_buffer} (via
    {!Jsip_dashboard_server.Exchange_feed}) and serves the browser side with
    {!Jsip_dashboard_server.Web_server}: the dashboard page, the js_of_ocaml
    bundle, and the [Jsip_dashboard_protocol.Recent_samples.rpc] poll over
    websockets.

    Dev loop:

    {v
      dune build
      dune exec app/scenario_runner/bin/main.exe -- \
        -scenario calm-day -port 12345 -seed 0
      dune exec app/dashboard/server/main.exe -- \
        -port 8080 -exchange-host localhost -exchange-port 12345
    v}

    then open http://localhost:8080. After a client-only change, [dune build]
    and a browser refresh suffice — the bundle is re-read per request, so the
    dashboard server keeps running. *)

open! Core
open! Async
open Jsip_dashboard_server

let default_port = 8080
let default_exchange_port = 12345

(* 300 one-per-second snapshots: five minutes of history, comfortably more
   than the browser client's two-minute window. *)
let sample_buffer_capacity = 300

let default_js_path =
  Filename.dirname Stdlib.Sys.executable_name ^/ "main.bc.js"
;;

let main ~port ~exchange_host ~exchange_port ~js_path () =
  let buffer = ref (Sample_buffer.create ~capacity:sample_buffer_capacity) in
  don't_wait_for
    (Exchange_feed.run
       ~host:exchange_host
       ~port:exchange_port
       ~on_sample:(fun sample -> buffer := Sample_buffer.add !buffer sample));
  let%bind server =
    Web_server.serve ~port ~js_path ~recent_samples:(fun query ->
      Sample_buffer.response !buffer ~query)
  in
  Log.Global.info_s
    [%message
      "dashboard server running"
        ~url:([%string "http://localhost:%{port#Int}"] : string)];
  Cohttp_async.Server.close_finished server
;;

let command =
  Command.async
    ~summary:
      "Bridge server for the browser dashboard: buffers exchange-stats \
       snapshots from a JSIP exchange and serves them, plus the dashboard \
       web app, over HTTP and websocket RPC."
    (let%map_open.Command port =
       flag
         "-port"
         (optional_with_default default_port int)
         ~doc:"PORT port to serve the dashboard on (default 8080)"
     and exchange_host =
       flag
         "-exchange-host"
         (optional_with_default "localhost" string)
         ~doc:"HOST exchange server hostname (default localhost)"
     and exchange_port =
       flag
         "-exchange-port"
         (optional_with_default default_exchange_port int)
         ~doc:"PORT exchange server port (default 12345)"
     and js_path =
       flag
         "-js"
         (optional_with_default default_js_path string)
         ~doc:
           "FILE path to the compiled client bundle main.bc.js (default: \
            next to this executable)"
     in
     fun () -> main ~port ~exchange_host ~exchange_port ~js_path ())
    ~behave_nicely_in_pipeline:false
;;

let () = Command_unix.run command
