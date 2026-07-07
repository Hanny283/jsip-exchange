(** Expect tests for {!Jsip_bots.Pump_and_dump}. *)

open! Core
open! Async
open! Jsip_types
open! Jsip_bots
open Bot_harness

let print_state (config : Pump_and_dump.Config.t) =
  let module For_testing = Pump_and_dump.Config.For_testing in
  printf
    !"phase=%{sexp:Pump_and_dump.Phase.t} position=%d realized_pnl_cents=%d\n"
    (For_testing.phase config)
    (For_testing.position config)
    (For_testing.realized_pnl_cents config)
;;

(* The whole scheme end to end: anchor at the fixed BBO's mid, accumulate a
   long on marketable buys, flip to distribute once the observed mid has run
   up past [pump_target_pct], unwind into the raised market, and land [Done]
   and flat. Fills are fed back so the position and P&L track a real run; the
   realized P&L is positive because we buy near 150.10 and sell near 152.00. *)
let%expect_test "pump-and-dump: accumulate, flip on price rise, then dump" =
  let config =
    Pump_and_dump.Config.create
      ~target_symbol:aapl
      ~pump_target_pct:(Percent.of_percentage 1.0)
      ~clip_size:20
      ~max_inventory:100
      ~give_up_ticks:100
      ~aggression_offset_cents:2
      ~entry_time_in_force:Ioc
  in
  let bot, submitted, _cancelled =
    make_recording_bot (module Pump_and_dump) config ()
  in
  (* Anchor at mid 150.00 from the fixed BBO (bid 149.90 / ask 150.10). *)
  let%bind () = feed_fixed_bbo bot in
  (* Two accumulate ticks; confirm each buy clip with a fill so the long
     grows. *)
  let%bind () = drive_ticks bot ~ticks:1 in
  let%bind () = feed_self_fill bot ~side:Buy ~price_cents:15011 ~size:20 in
  let%bind () = drive_ticks bot ~ticks:1 in
  let%bind () = feed_self_fill bot ~side:Buy ~price_cents:15012 ~size:20 in
  print_state config;
  (* The market has now run up past the 1% target (mid 152.00 >= 151.50); the
     next tick flips to Distribute and submits nothing that tick. *)
  let%bind () = feed_bbo bot ~bid_cents:15190 ~ask_cents:15210 in
  let%bind () = drive_ticks bot ~ticks:1 in
  print_state config;
  (* Distribute: sell clips until flat, feeding each sell back. *)
  let%bind () = drive_ticks bot ~ticks:1 in
  let%bind () = feed_self_fill bot ~side:Sell ~price_cents:15200 ~size:20 in
  let%bind () = drive_ticks bot ~ticks:1 in
  let%bind () = feed_self_fill bot ~side:Sell ~price_cents:15200 ~size:20 in
  print_state config;
  (* Flat now, so the next tick lands [Done]. *)
  let%bind () = drive_ticks bot ~ticks:1 in
  print_state config;
  print_submitted submitted;
  [%expect
    {|
    phase=Accumulate position=40 realized_pnl_cents=-600460
    phase=Distribute position=40 realized_pnl_cents=-600460
    phase=Distribute position=0 realized_pnl_cents=7540
    phase=Done position=0 realized_pnl_cents=7540
    BUY AAPL 20@$150.12 IOC
    BUY AAPL 20@$150.13 IOC
    SELL AAPL 20@$151.88 IOC
    SELL AAPL 20@$151.87 IOC
    |}];
  return ()
;;

(* When the price never rises to the target, the [give_up_ticks] budget still
   flips the scheme to Distribute so it unwinds rather than holding forever
   -- the honest "scheme failed" path. Here it buys into a flat market and
   dumps back into it at a loss. *)
let%expect_test "pump-and-dump: give_up_ticks unwinds a failed pump" =
  let config =
    Pump_and_dump.Config.create
      ~target_symbol:aapl
      ~pump_target_pct:(Percent.of_percentage 50.0)
      ~clip_size:10
      ~max_inventory:100
      ~give_up_ticks:3
      ~aggression_offset_cents:2
      ~entry_time_in_force:Ioc
  in
  let bot, _submitted, _cancelled =
    make_recording_bot (module Pump_and_dump) config ()
  in
  let%bind () = feed_fixed_bbo bot in
  (* Two buys into a flat market, then the third tick hits the give-up budget
     and flips to Distribute without buying. *)
  let%bind () = drive_ticks bot ~ticks:1 in
  let%bind () = feed_self_fill bot ~side:Buy ~price_cents:15011 ~size:10 in
  let%bind () = drive_ticks bot ~ticks:1 in
  let%bind () = feed_self_fill bot ~side:Buy ~price_cents:15011 ~size:10 in
  let%bind () = drive_ticks bot ~ticks:1 in
  print_state config;
  (* Unwind the 20-share long at the (unchanged, weak) bid. *)
  let%bind () = drive_ticks bot ~ticks:1 in
  let%bind () = feed_self_fill bot ~side:Sell ~price_cents:14989 ~size:10 in
  let%bind () = drive_ticks bot ~ticks:1 in
  let%bind () = feed_self_fill bot ~side:Sell ~price_cents:14989 ~size:10 in
  let%bind () = drive_ticks bot ~ticks:1 in
  print_state config;
  [%expect
    {|
    phase=Distribute position=20 realized_pnl_cents=-300220
    phase=Done position=0 realized_pnl_cents=-440
    |}];
  return ()
;;
