open! Core
open Jsip_types
open Jsip_pnl
open Jsip_test_harness
open Harness

(* Build a fill directly, without going through the matching engine, so tests
   can script exact trade sequences. [aggressor]/[aggressor_side] name the
   incoming order; [resting] takes the opposite side of the same trade. The
   order-id and client-order-id fields don't affect P&L, so we fill them with
   throwaway values. *)
let fill ~aggressor ~aggressor_side ~resting ~price_cents ~size : Fill.t =
  { fill_id = 0
  ; symbol = aapl
  ; price = Price.of_int_cents price_cents
  ; size = Size.of_int size
  ; aggressor_order_id = Order_id.For_testing.of_int 1
  ; aggressor_participant = aggressor
  ; aggressor_side
  ; resting_order_id = Order_id.For_testing.of_int 2
  ; resting_participant = resting
  ; aggressor_client_order_id = Client_order_id.of_string "1"
  ; resting_client_order_id = Client_order_id.of_string "2"
  }
;;

let trade_print ~price_cents : Exchange_event.t =
  Trade_report
    { symbol = aapl; price = Price.of_int_cents price_cents; size = Size.of_int 1 }
;;

let print_summary pnl participant =
  print_s [%sexp (Pnl.summary pnl participant : Pnl.Summary.t)]
;;

(* Alice buys 200 (in two lots) then sells 100; Bob is the counterparty on
   every trade, so his book is Alice's mirror image. A trade print at $158
   then marks both open positions. *)
let%expect_test "build up, partially close, then mark to a trade print" =
  let pnl =
    Pnl.empty
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Buy ~resting:bob
         ~price_cents:15000 ~size:100)
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Buy ~resting:bob
         ~price_cents:15200 ~size:100)
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Sell ~resting:bob
         ~price_cents:15500 ~size:100)
    |> fun t -> Pnl.apply_trade_report t (trade_print ~price_cents:15800)
  in
  print_summary pnl alice;
  [%expect {|
    ((per_symbol
      (((symbol AAPL) (inventory 100) (average_entry (15100))
        (reference_price (15800)) (realized_cents 40000)
        (unrealized_cents 70000))))
     (total_realized_cents 40000) (total_unrealized_cents 70000))
    |}];
  print_summary pnl bob;
  [%expect {|
    ((per_symbol
      (((symbol AAPL) (inventory -100) (average_entry (15100))
        (reference_price (15800)) (realized_cents -40000)
        (unrealized_cents -70000))))
     (total_realized_cents -40000) (total_unrealized_cents -70000))
    |}]
;;

(* Closing a long all the way back to flat realizes everything and leaves no
   open position to mark, so unrealized is zero regardless of the print. *)
let%expect_test "closing to flat realizes fully and leaves nothing to mark" =
  let pnl =
    Pnl.empty
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Buy ~resting:bob
         ~price_cents:10000 ~size:50)
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Sell ~resting:bob
         ~price_cents:10300 ~size:50)
    |> fun t -> Pnl.apply_trade_report t (trade_print ~price_cents:99999)
  in
  print_summary pnl alice;
  [%expect {|
    ((per_symbol
      (((symbol AAPL) (inventory 0) (average_entry ()) (reference_price (99999))
        (realized_cents 15000) (unrealized_cents 0))))
     (total_realized_cents 15000) (total_unrealized_cents 0))
    |}]
;;
