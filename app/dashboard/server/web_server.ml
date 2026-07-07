open! Core
open! Async
module Recent_samples = Jsip_dashboard_protocol.Recent_samples

let html_headers =
  Cohttp.Header.of_list [ "Content-Type", "text/html; charset=utf-8" ]
;;

let js_headers =
  Cohttp.Header.of_list [ "Content-Type", "application/javascript" ]
;;

let not_found =
  Cohttp_async.Server.respond_string ~status:`Not_found "Not found"
;;

(* Plain-HTTP fallback for requests that are not websocket upgrades. The
   bundle at [js_path] is read per request (no caching) so a rebuilt client
   is picked up by a browser refresh alone. *)
let http_handler
  ~js_path
  ~body:(_ : Cohttp_async.Body.t)
  (_ : Socket.Address.Inet.t)
  (request : Cohttp_async.Request.t)
  =
  match Cohttp_async.Request.meth request with
  | `GET ->
    (match Uri.path (Cohttp_async.Request.uri request) with
     | "/" | "/index.html" ->
       Cohttp_async.Server.respond_string
         ~headers:html_headers
         Static_page.index_html
     | "/main.bc.js" ->
       Cohttp_async.Server.respond_with_file ~headers:js_headers js_path
     | (_ : string) -> not_found)
  | `HEAD | `POST | `PUT | `DELETE | `PATCH | `OPTIONS | `TRACE | `CONNECT
  | `Other (_ : string) ->
    not_found
;;

let implementations ~recent_samples =
  Rpc.Implementations.create_exn
    ~implementations:
      [ Rpc.Rpc.implement' Recent_samples.rpc (fun () query ->
          recent_samples query)
      ]
    ~on_unknown_rpc:`Close_connection
    ~on_exception:Log_on_background_exn
;;

let serve ~port ~js_path ~recent_samples =
  Rpc_websocket.Rpc.serve
    ~where_to_listen:(Tcp.Where_to_listen.of_port port)
    ~implementations:(implementations ~recent_samples)
    ~initial_connection_state:
      (fun
        ()
        (_ : Rpc_websocket.Rpc.Connection_initiated_from.t)
        (_ : Socket.Address.Inet.t)
        (_ : Rpc.Connection.t)
      -> ())
    ~http_handler:(fun () -> http_handler ~js_path)
    ~on_handler_error:`Ignore
    ()
;;
