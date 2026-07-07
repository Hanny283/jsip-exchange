open! Core
open! Async
open Jsip_types
open Jsip_bot_runtime
open! Jsip_bots
open Bot_harness

let aapl = Symbol.of_string "AAPL"

(* A synthetic two-sided market for the bot to peg against. *)
let bbo ~bid_cents ~ask_cents : Bbo.t =
  { bid =
      Some { price = Price.of_int_cents bid_cents; size = Size.of_int 100 }
  ; ask =
      Some { price = Price.of_int_cents ask_cents; size = Size.of_int 100 }
  }
;;

(* One flood should post [orders_per_burst] orders on each side, each one
   tick inside the opposite quote. Every buy should sit one cent below the
   ask and every sell one cent above the bid. *)
let%expect_test "one flood pegs a burst one tick inside each side of the BBO"
  =
  let config =
    Quote_stuffer.Config.create
      ~symbols:[ aapl ]
      ~orders_per_burst:2
      ~order_size:(Size.of_int 1)
  in
  let bot, submitted, _cancelled =
    make_recording_bot (module Quote_stuffer) config ()
  in
  let ctx = Bot_runtime.For_testing.context_of bot in
  let%bind () =
    Bot_runtime.feed_event
      bot
      (Best_bid_offer_update
         { symbol = aapl; bbo = bbo ~bid_cents:14900 ~ask_cents:15100 })
  in
  let%bind () = Quote_stuffer.on_tick config ctx in
  print_submitted submitted;
  [%expect
    {|
    BUY AAPL 1@$150.99 DAY
    BUY AAPL 1@$150.99 DAY
    SELL AAPL 1@$149.01 DAY
    SELL AAPL 1@$149.01 DAY
    |}];
  return ()
;;

(*= 2026-07-07 13:38:48.919785Z Info quote_stuffed
    2026-07-07 13:38:48.923497Z Info quote_stuffed
    2026-07-07 13:38:48.923512Z Info quote_stuffed
    2026-07-07 13:38:48.923517Z Info quote_stuffed *)

(* Guards the fresh-id requirement: reusing a [client_order_id] would make
   the engine reject every submit after the first. *)
let%expect_test "each stuffed order carries a distinct client_order_id" =
  let config =
    Quote_stuffer.Config.create
      ~symbols:[ aapl ]
      ~orders_per_burst:3
      ~order_size:(Size.of_int 1)
  in
  let bot, submitted, _cancelled =
    make_recording_bot (module Quote_stuffer) config ()
  in
  let ctx = Bot_runtime.For_testing.context_of bot in
  let%bind () =
    Bot_runtime.feed_event
      bot
      (Best_bid_offer_update
         { symbol = aapl; bbo = bbo ~bid_cents:14900 ~ask_cents:15100 })
  in
  let%bind () = Quote_stuffer.on_tick config ctx in
  let ids =
    List.map !submitted ~f:(fun (req : Order.Request.t) ->
      req.client_order_id)
  in
  let distinct =
    List.contains_dup ids ~compare:Client_order_id.compare |> not
  in
  printf "distinct ids: %b (%d orders)\n" distinct (List.length ids);
  [%expect {| distinct ids: true (6 orders) |}];
  return ()
;;

(* Drive several ticks while the market moves underneath the bot. Each tick
   should re-peg to the *latest* BBO — one tick below the current ask, one
   tick above the current bid — never to a stale quote. With
   [orders_per_burst:1] every tick contributes exactly one buy then one sell,
   so the submitted stream is a clean per-tick trace. *)
let%expect_test "successive ticks re-peg to the latest BBO" =
  let config =
    Quote_stuffer.Config.create
      ~symbols:[ aapl ]
      ~orders_per_burst:1
      ~order_size:(Size.of_int 1)
  in
  let bot, submitted, _cancelled =
    make_recording_bot (module Quote_stuffer) config ()
  in
  let ctx = Bot_runtime.For_testing.context_of bot in
  let tick ~bid_cents ~ask_cents =
    let%bind () =
      Bot_runtime.feed_event
        bot
        (Best_bid_offer_update
           { symbol = aapl; bbo = bbo ~bid_cents ~ask_cents })
    in
    Quote_stuffer.on_tick config ctx
  in
  let%bind () = tick ~bid_cents:14900 ~ask_cents:15100 in
  let%bind () = tick ~bid_cents:14950 ~ask_cents:15150 in
  let%bind () = tick ~bid_cents:14800 ~ask_cents:15000 in
  print_submitted submitted;
  [%expect
    {|
    BUY AAPL 1@$150.99 DAY
    SELL AAPL 1@$149.01 DAY
    BUY AAPL 1@$151.49 DAY
    SELL AAPL 1@$149.51 DAY
    BUY AAPL 1@$149.99 DAY
    SELL AAPL 1@$148.01 DAY
    |}];
  return ()
;;
