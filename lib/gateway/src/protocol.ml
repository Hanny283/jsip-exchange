open! Core
open Jsip_types

let format_event ?symbols event =
  (* Render a symbol id through the directory mirror when the caller holds
     one (the client and monitor, post-connect), and as the raw id otherwise
     (engine-level tests, or before the directory is fetched). Total either
     way: an id the mirror doesn't know falls back to the raw int rather than
     raising mid-render. *)
  let symbol_string id =
    match
      Option.bind symbols ~f:(fun registry ->
        Symbol_registry.name registry id)
    with
    | Some name -> Symbol.to_string name
    | None -> Symbol_id.to_string id
  in
  match event with
  | Exchange_event.Order_accept { order_id; participant = _; request } ->
    sprintf
      "ACCEPTED id=%s %s %s %d@%s %s"
      (Order_id.to_string order_id)
      (symbol_string request.symbol)
      (Side.to_string request.side)
      (Size.to_int request.size)
      (Price.to_string_dollar request.price)
      (Time_in_force.to_string request.time_in_force)
  | Fill fill ->
    let fill_str =
      Fill.to_string_with_symbol fill ~symbol:(symbol_string fill.symbol)
    in
    [%string "FILL %{fill_str}"]
  | Order_cancel
      { order_id
      ; participant = _
      ; symbol
      ; remaining_size
      ; reason
      ; client_order_id
      } ->
    sprintf
      "CANCELLED client_id=%s id=%s %s remaining=%d reason=%s"
      (Client_order_id.to_string client_order_id)
      (Order_id.to_string order_id)
      (symbol_string symbol)
      (Size.to_int remaining_size)
      (Cancel_reason.to_string reason)
  | Order_reject { participant = _; request; reason } ->
    sprintf
      "REJECTED %s %s %d@%s reason=%s"
      (symbol_string request.symbol)
      (Side.to_string request.side)
      (Size.to_int request.size)
      (Price.to_string_dollar request.price)
      reason
  | Best_bid_offer_update { symbol; bbo } ->
    let symbol = symbol_string symbol in
    let bid = Level.opt_to_string bbo.bid in
    let ask = Level.opt_to_string bbo.ask in
    [%string "BBO %{symbol} bid=%{bid} ask=%{ask}"]
  | Trade_report { symbol; price; size } ->
    let symbol = symbol_string symbol in
    let size = Size.to_int size in
    [%string "TRADE %{symbol} %{price#Price} x%{size#Int}"]
  | Cancel_reject { participant; client_order_id; reason } ->
    [%string
      "CANCEL: %{participant#Participant} \
       %{client_order_id#Client_order_id} %{reason}"]
;;

let format_events ?symbols events =
  List.map events ~f:(format_event ?symbols) |> String.concat ~sep:"\n"
;;
