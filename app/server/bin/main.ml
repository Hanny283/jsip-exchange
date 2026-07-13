(** Exchange server.

    Runs the matching engine and listens for RPC connections from clients.

    Run with: dune exec app/server/bin/main.exe -- -port 12345

    Automated market-making and trading activity now lives in the scenario
    runner (see [app/scenario_runner]); this binary just brings up a bare
    exchange for clients (and scenarios) to connect to. *)

open! Core
open! Async
open Jsip_types
open Jsip_gateway

let default_symbols =
  [ Symbol.of_string "AAPL"
  ; Symbol.of_string "TSLA"
  ; Symbol.of_string "GOOG"
  ; Symbol.of_string "MSFT"
  ]
;;

let start ~port =
  (* main owns the id authority: the i-th symbol of [default_symbols] is id
     i, and the directory RPC serves this mapping to every connecting client. *)
  let symbol_registry = Symbol_registry.of_symbols default_symbols in
  let%bind server = Exchange_server.start ~symbol_registry ~port () in
  print_endline
    [%string
      "JSIP Exchange server listening on port %{Exchange_server.port \
       server#Int}"];
  let symbols =
    Symbol_registry.to_directory symbol_registry
    |> List.map ~f:(fun (name, id) ->
      [%string "%{id#Symbol_id}=%{name#Symbol}"])
    |> String.concat ~sep:" "
  in
  print_endline [%string "Trading: %{symbols}"];
  Exchange_server.close_finished server
;;

let () =
  Command.async
    ~summary:"JSIP Exchange server"
    (let%map_open.Command port =
       flag "-port" (required int) ~doc:"PORT port to listen on"
     in
     fun () -> start ~port)
  |> Command_unix.run
;;
