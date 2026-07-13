(** Wire payload sizes, in bytes, for the types that actually ship on the
    wire — the bandwidth half of the symbol-as-int payoff.

    [bin_size_t] is a deterministic byte count, so these are expect tests
    rather than benchmarks. For scale: a bin_io string costs a length byte
    plus its characters ("AAPL" = 5 bytes), while a small int id costs 1 byte
    — so every symbol field below is 4 bytes slimmer than its string-era
    self, on every order and every streamed event. *)

open! Core
open Jsip_types

let request : Order.Request.t =
  { symbol = Symbol_id.of_int 0
  ; side = Buy
  ; price = Price.of_int_cents 15000
  ; size = Size.of_int 100
  ; time_in_force = Day
  ; client_order_id = Client_order_id.of_string "1"
  }
;;

let fill : Fill.t =
  { fill_id = 1
  ; symbol = Symbol_id.of_int 0
  ; price = Price.of_int_cents 15000
  ; size = Size.of_int 100
  ; aggressor_order_id = Order_id.of_string "2"
  ; aggressor_participant = Participant.of_string "Alice"
  ; aggressor_side = Buy
  ; resting_order_id = Order_id.of_string "1"
  ; resting_participant = Participant.of_string "Bob"
  ; aggressor_client_order_id = Client_order_id.of_string "2"
  ; resting_client_order_id = Client_order_id.of_string "1"
  }
;;

let book : Book.t =
  { symbol = Symbol_id.of_int 0
  ; bids = [ { price = Price.of_int_cents 14990; size = Size.of_int 100 } ]
  ; asks = [ { price = Price.of_int_cents 15010; size = Size.of_int 200 } ]
  ; bbo =
      { bid =
          Some { price = Price.of_int_cents 14990; size = Size.of_int 100 }
      ; ask =
          Some { price = Price.of_int_cents 15010; size = Size.of_int 200 }
      }
  }
;;

let%expect_test "wire payload sizes in bytes" =
  let sizes =
    [ "Order.Request", Order.Request.bin_size_t request
    ; "Fill", Fill.bin_size_t fill
    ; "Book", Book.bin_size_t book
    ; ( "Exchange_event (Fill)"
      , Exchange_event.bin_size_t (Exchange_event.Fill fill) )
    ; ( "Exchange_event (Trade_report)"
      , Exchange_event.bin_size_t
          (Trade_report
             { symbol = Symbol_id.of_int 0
             ; price = Price.of_int_cents 15000
             ; size = Size.of_int 100
             }) )
    ]
  in
  List.iter sizes ~f:(fun (name, bytes) ->
    print_endline [%string "%{name}: %{bytes#Int} bytes"]);
  [%expect
    {|
    Order.Request: 8 bytes
    Fill: 21 bytes
    Book: 25 bytes
    Exchange_event (Fill): 22 bytes
    Exchange_event (Trade_report): 6 bytes
    |}]
;;
