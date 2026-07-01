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
let fill ?(symbol = aapl) ~aggressor ~aggressor_side ~resting ~price_cents ~size
  ()
  : Fill.t
  =
  { fill_id = 0
  ; symbol
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

let trade_print ?(symbol = aapl) ~price_cents () : Exchange_event.t =
  Trade_report
    { symbol; price = Price.of_int_cents price_cents; size = Size.of_int 1 }
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
         ~price_cents:15000 ~size:100 ())
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Buy ~resting:bob
         ~price_cents:15200 ~size:100 ())
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Sell ~resting:bob
         ~price_cents:15500 ~size:100 ())
    |> fun t -> Pnl.apply_trade_report t (trade_print ~price_cents:15800 ())
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
         ~price_cents:10000 ~size:50 ())
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Sell ~resting:bob
         ~price_cents:10300 ~size:50 ())
    |> fun t -> Pnl.apply_trade_report t (trade_print ~price_cents:99999 ())
  in
  print_summary pnl alice;
  [%expect {|
    ((per_symbol
      (((symbol AAPL) (inventory 0) (average_entry ()) (reference_price (99999))
        (realized_cents 15000) (unrealized_cents 0))))
     (total_realized_cents 15000) (total_unrealized_cents 0))
    |}]
;;

(* Alice sells 100 @ $150 to open a short (cost basis -1,500,000 at avg 15000),
   then buys back 40 @ $140 (below entry). Covering a short below entry is a
   profit: realized = sign(-100) * min(40,100) * (14000 - 15000)
   = -1 * 40 * -1000 = +40,000. The residual is -60 short with the average
   entry unchanged at 15000. Marked at 14000, unrealized
   = -60 * (14000 - 15000) = +60,000 — a short gains as the price falls. *)
let%expect_test "cover a short below entry realizes a profit" =
  let pnl =
    Pnl.empty
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Sell ~resting:bob
         ~price_cents:15000 ~size:100 ())
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Buy ~resting:bob
         ~price_cents:14000 ~size:40 ())
    |> fun t -> Pnl.apply_trade_report t (trade_print ~price_cents:14000 ())
  in
  print_summary pnl alice;
  [%expect
    {|
    ((per_symbol
      (((symbol AAPL) (inventory -60) (average_entry (15000))
        (reference_price (14000)) (realized_cents 40000)
        (unrealized_cents 60000))))
     (total_realized_cents 40000) (total_unrealized_cents 60000))
    |}]
;;

(* Alice buys 100 @ $150 (long, avg 15000), then a single sell of 150 @ $160
   flips her through flat into a 50-lot short. The closed 100-share slice
   realizes against the OLD average entry: sign(100) * min(150,100)
   * (16000 - 15000) = +100,000. The leftover -50 is re-opened at the trade
   price, so its average_entry is 16000, not the old 15000. Marked at 16500,
   unrealized = -50 * (16500 - 16000) = -25,000 — a short loses as price
   rises. *)
let%expect_test "a single sell flips a long through flat into a short" =
  let pnl =
    Pnl.empty
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Buy ~resting:bob
         ~price_cents:15000 ~size:100 ())
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~aggressor:alice ~aggressor_side:Sell ~resting:bob
         ~price_cents:16000 ~size:150 ())
    |> fun t -> Pnl.apply_trade_report t (trade_print ~price_cents:16500 ())
  in
  print_summary pnl alice;
  [%expect
    {|
    ((per_symbol
      (((symbol AAPL) (inventory -50) (average_entry (16000))
        (reference_price (16500)) (realized_cents 100000)
        (unrealized_cents -25000))))
     (total_realized_cents 100000) (total_unrealized_cents -25000))
    |}]
;;

(* Alice trades two symbols, each marked by its own trade print.
   AAPL: buy 100 @ $100, sell 40 @ $110 -> realized = 40 * (11000 - 10000)
   = 40,000; residual 60 long at avg 10000, marked at 11000 ->
   unrealized = 60 * (11000 - 10000) = 60,000.
   TSLA: buy 50 @ $200, marked at $190 -> realized 0,
   unrealized = 50 * (19000 - 20000) = -50,000.
   Totals sum across symbols: realized = 40,000 + 0 = 40,000;
   unrealized = 60,000 + (-50,000) = 10,000. *)
let%expect_test "summary sums realized and unrealized across symbols" =
  let pnl =
    Pnl.empty
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~symbol:aapl ~aggressor:alice ~aggressor_side:Buy ~resting:bob
         ~price_cents:10000 ~size:100 ())
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~symbol:aapl ~aggressor:alice ~aggressor_side:Sell ~resting:bob
         ~price_cents:11000 ~size:40 ())
    |> fun t ->
    Pnl.apply_fill
      t
      (fill ~symbol:tsla ~aggressor:alice ~aggressor_side:Buy ~resting:bob
         ~price_cents:20000 ~size:50 ())
    |> fun t ->
    Pnl.apply_trade_report t (trade_print ~symbol:aapl ~price_cents:11000 ())
    |> fun t ->
    Pnl.apply_trade_report t (trade_print ~symbol:tsla ~price_cents:19000 ())
  in
  print_summary pnl alice;
  [%expect
    {|
    ((per_symbol
      (((symbol AAPL) (inventory 60) (average_entry (10000))
        (reference_price (11000)) (realized_cents 40000)
        (unrealized_cents 60000))
       ((symbol TSLA) (inventory 50) (average_entry (20000))
        (reference_price (19000)) (realized_cents 0) (unrealized_cents -50000))))
     (total_realized_cents 40000) (total_unrealized_cents 10000))
    |}]
;;
