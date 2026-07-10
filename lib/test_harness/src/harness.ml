open! Core
open Jsip_types
open Jsip_order_book
open Jsip_gateway

(* --- Constants --- *)

(* The standard test symbol set is positional: AAPL is id 0, TSLA id 1, GOOG
   id 2, and [create]'s default engine trades exactly those three ids. Every
   fixture in the suite maps through this one place. *)
let aapl = Symbol_id.of_int 0
let tsla = Symbol_id.of_int 1
let goog = Symbol_id.of_int 2
let alice = Participant.of_string "Alice"
let bob = Participant.of_string "Bob"
let charlie = Participant.of_string "Charlie"
let market_maker = Participant.of_string "MarketMaker"

(* --- Harness --- *)

type t = { engine : Matching_engine.t }

let create ?(num_symbols = 3) () =
  { engine = Matching_engine.create ~num_symbols }
;;

let engine t = t.engine

(* --- Builders --- *)

(* The matching engine rejects a repeated [(participant, client_order_id)],
   so builders hand out a fresh id on every call unless the test pins one
   explicitly. Tests that care about a specific id pass [~client_order_id]. *)
let client_order_id_gen = Client_order_id.Generator.create ()

let make_request
  ~side
  ~price_cents
  ?(size = 100)
  ?(symbol = aapl)
  ?(time_in_force = Time_in_force.Day)
  ?(client_order_id = Client_order_id.Generator.next client_order_id_gen)
  ()
  : Order.Request.t
  =
  { symbol
  ; side
  ; price = Price.of_int_cents price_cents
  ; size = Size.of_int size
  ; time_in_force
  ; client_order_id
  }
;;

let buy ~price_cents ?size ?symbol ?time_in_force () =
  make_request ~side:Buy ~price_cents ?size ?symbol ?time_in_force ()
;;

let sell ~price_cents ?size ?symbol ?time_in_force () =
  make_request ~side:Sell ~price_cents ?size ?symbol ?time_in_force ()
;;

(* --- Formatting --- *)

module Show = struct
  type t = Exchange_event.t -> bool

  let all _ = true
  let only f = f
  let no_market_data event = not (Exchange_event.is_market_data event)
end

let print_events ?(show = Show.all) events =
  List.iter events ~f:(fun event ->
    if show event then print_endline (Protocol.format_event event))
;;

let print_event event = print_endline (Protocol.format_event event)

(* Identity travels with the submission, not the order text — the same shape
   as the real gateway, where the session stamps the participant. Tests that
   don't care default to [alice]. *)
let submit ?(participant = alice) t request =
  let events = Matching_engine.submit t.engine request ~participant in
  print_events events;
  events
;;

let submit_ ?participant t request =
  ignore (submit ?participant t request : Exchange_event.t list)
;;

let submit_quiet ?(participant = alice) t request =
  Matching_engine.submit (engine t) request ~participant
;;

let sample_events : Exchange_event.t list =
  let order_request : Order.Request.t =
    { symbol = aapl
    ; side = Buy
    ; price = Price.of_int_cents 15000
    ; size = Size.of_int 100
    ; time_in_force = Day
    ; client_order_id = Client_order_id.of_string "1"
    }
  in
  [ Order_accept
      { order_id = Order_id.For_testing.of_int 1
      ; participant = alice
      ; request = order_request
      }
  ; Fill
      { fill_id = 1
      ; symbol = aapl
      ; price = Price.of_int_cents 15000
      ; size = Size.of_int 100
      ; aggressor_order_id = Order_id.For_testing.of_int 2
      ; aggressor_participant = alice
      ; aggressor_side = Buy
      ; resting_order_id = Order_id.For_testing.of_int 1
      ; resting_participant = bob
      ; aggressor_client_order_id = Client_order_id.of_string "2"
      ; resting_client_order_id = Client_order_id.of_string "1"
      }
  ; Order_cancel
      { order_id = Order_id.For_testing.of_int 1
      ; participant = alice
      ; symbol = aapl
      ; remaining_size = Size.of_int 50
      ; reason = Ioc_remainder
      ; client_order_id = Client_order_id.of_string "1"
      }
  ; Order_reject
      { participant = alice
      ; request = order_request
      ; reason = "unknown symbol"
      }
  ; Best_bid_offer_update
      { symbol = aapl
      ; bbo =
          { bid =
              Some
                { price = Price.of_int_cents 14990; size = Size.of_int 100 }
          ; ask =
              Some
                { price = Price.of_int_cents 15010; size = Size.of_int 200 }
          }
      }
  ; Trade_report
      { symbol = aapl
      ; price = Price.of_int_cents 15000
      ; size = Size.of_int 100
      }
  ]
;;

let submit_quiet_ ?participant t request =
  ignore (submit_quiet ?participant t request : Exchange_event.t list)
;;

let print_book t symbol =
  match Matching_engine.book t.engine symbol with
  | None -> print_endline [%string "unknown symbol %{symbol#Symbol_id}"]
  | Some book -> Order_book.snapshot book |> Book.to_string |> print_endline
;;

let print_bbo t symbol =
  match Matching_engine.book t.engine symbol with
  | None -> print_endline [%string "BBO %{symbol#Symbol_id}: unknown symbol"]
  | Some book ->
    let bbo = Order_book.best_bid_offer book |> Bbo.to_string in
    print_endline [%string "BBO %{symbol#Symbol_id}: %{bbo}"]
;;
