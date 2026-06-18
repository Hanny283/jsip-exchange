open! Core
open Jsip_types

(* Default participant when no "as <name>" is specified in the command.
   [parse_command_with_default_participant] overrides this with the
   caller-supplied default. *)
let default_participant = Participant.of_string "anonymous"

(* let parse_command_with_default_participant line ~default = match
   parse_command line with | Error _ as err -> err | Ok request -> if
   Participant.equal request.participant default_participant then Ok
   [{ request with participant = default }] else Ok request ;; *)

let format_event = function
  | Exchange_event.Order_accept { order_id; request } ->
    sprintf
      "ACCEPTED id=%s %s %s %d@%s %s"
      (Order_id.to_string order_id)
      (Symbol.to_string request.symbol)
      (Side.to_string request.side)
      (Size.to_int request.size)
      (Price.to_string_dollar request.price)
      (Time_in_force.to_string request.time_in_force)
  | Fill fill -> [%string "FILL %{fill#Fill}"]
  | Order_cancel
      { order_id; participant = _; symbol; remaining_size; reason } ->
    sprintf
      "CANCELLED id=%s %s remaining=%d reason=%s"
      (Order_id.to_string order_id)
      (Symbol.to_string symbol)
      (Size.to_int remaining_size)
      (Cancel_reason.to_string reason)
  | Order_reject { request; reason } ->
    sprintf
      "REJECTED %s %s %d@%s reason=%s"
      (Symbol.to_string request.symbol)
      (Side.to_string request.side)
      (Size.to_int request.size)
      (Price.to_string_dollar request.price)
      reason
  | Best_bid_offer_update { symbol; bbo } ->
    let bid = Level.opt_to_string bbo.bid in
    let ask = Level.opt_to_string bbo.ask in
    [%string "BBO %{symbol#Symbol} bid=%{bid} ask=%{ask}"]
  | Trade_report { symbol; price; size } ->
    let size = Size.to_int size in
    [%string "TRADE %{symbol#Symbol} %{price#Price} x%{size#Int}"]
;;

let format_events events =
  List.map events ~f:format_event |> String.concat ~sep:"\n"
;;
