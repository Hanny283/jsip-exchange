open! Core

type t =
  | Order_accept of
      { order_id : Order_id.t
      ; request : Order.Request.t
      }
  | Fill of Fill.t
  | Order_cancel of
      { order_id : Order_id.t
      ; participant : Participant.t
      ; symbol : Symbol.t
      ; remaining_size : Size.t
      ; reason : Cancel_reason.t
      ; client_order_id : Client_order_id.t
      }
  | Order_reject of
      { request : Order.Request.t
      ; reason : string
      }
  | Best_bid_offer_update of
      { symbol : Symbol.t
      ; bbo : Bbo.t
      }
  | Trade_report of
      { symbol : Symbol.t
      ; price : Price.t
      ; size : Size.t
      }
  | Cancel_reject of
      { participant : Participant.t
      ; client_order_id : Client_order_id.t
      ; reason : string
      }
[@@deriving sexp, bin_io]

let to_string_hum event =
  match event with
  | Order_accept event ->
    "Your order "
    ^ Order_id.to_string event.order_id
    ^ "for "
    ^ Order.Request.to_string event.request
    ^ " was accepted "
  | Fill event ->
    "Your order "
    ^ Size.to_string event.size
    ^ " "
    ^ Symbol.to_string event.symbol
    ^ " filled at "
    ^ Price.to_string event.price
  | Order_cancel event ->
    "You canceled your order " ^ Order_id.to_string event.order_id
  | Order_reject event ->
    "Your order for "
    ^ Order.Request.to_string event.request
    ^ " "
    ^ Order.Request.to_string event.request
    ^ " was rejected"
  | Best_bid_offer_update event ->
    "The BBO for "
    ^ Symbol.to_string event.symbol
    ^ " is "
    ^ Bbo.to_string event.bbo
  | Trade_report event ->
    [%string
      "Trade Report: %{event.symbol#Symbol} %{event.price#Price} \
       %{event.size#Size}"]
  | Cancel_reject event ->
    [%string
      "Cancel Rejected: %{event.participant#Participant} \
       %{event.client_order_id#Client_order_id}. Reason: %{event.reason}"]
;;

let is_market_data = function
  | Best_bid_offer_update _ | Trade_report _ -> true
  | Order_accept _ | Fill _ | Order_cancel _ | Order_reject _
  | Cancel_reject _ ->
    false
;;

let symbol_of_market_data = function
  | Best_bid_offer_update { symbol; bbo = _ }
  | Trade_report { symbol; price = _; size = _ } ->
    Some symbol
  | Order_accept _ | Fill _ | Order_cancel _ | Order_reject _
  | Cancel_reject _ ->
    None
;;
