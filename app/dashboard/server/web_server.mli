(** The dashboard's HTTP-and-websocket front end.

    One [Cohttp_async] server does double duty: requests that ask for a
    websocket upgrade become Async-RPC connections serving
    {!Jsip_dashboard_protocol.Recent_samples.rpc} (the browser client polls
    it about once a second), while plain HTTP requests get the client app
    itself — {!Static_page.index_html} at ["/"] and the compiled js_of_ocaml
    bundle at ["/main.bc.js"]. *)

open! Core
open! Async

(** [serve ~port ~js_path ~recent_samples] starts the server listening on
    [port] and returns it once it is accepting connections; wait on
    [Cohttp_async.Server.close_finished] to keep it running.

    [recent_samples] answers each RPC poll — in practice from the server's
    current {!Sample_buffer}. It runs in the RPC handler, so it must not
    block.

    [js_path] points at the compiled client bundle. The file is re-read from
    disk on every request rather than cached, so rebuilding the client and
    refreshing the browser needs no server restart; a missing file surfaces
    as an error response for that request only.

    Requests for unknown paths get a 404; handler errors are ignored, so one
    bad request cannot take the server down. *)
val serve
  :  port:int
  -> js_path:string
  -> recent_samples:
       (Jsip_dashboard_protocol.Recent_samples.Query.t
        -> Jsip_dashboard_protocol.Recent_samples.Response.t)
  -> (Socket.Address.Inet.t, int) Cohttp_async.Server.t Deferred.t
