(** Unit tests for {!Market_maker_bot}.

    We drive the real bot through {!Jsip_bot_runtime.Bot_runtime} with mock
    [submit]/[cancel] closures that record what the bot does, and assert on
    the recorded {!Order.Request.t}s and cancellations. Nothing here
    reimplements the bot's pricing — we only observe it.

    The oracle is pinned to a known fundamental (no volatility, no mean
    reversion) so the ladder is deterministic, and the config is chosen to
    neutralise the adaptive parts of the strategy: [min_half_spread_cents]
    equals [half_spread_cents], and [max_spread_cents] is huge, so the
    half-spread never drifts and the maker never stands aside. *)

open! Core
open! Async
open Jsip_types
open Jsip_fundamental
open Jsip_bot_runtime
module Harness = Jsip_test_harness.Harness
module Market_maker_bot = Jsip_market_maker.Market_maker_bot

let aapl = Harness.aapl
let alice = Harness.alice
let bob = Harness.bob
let fair_value_cents = 15000

let oracle_config =
  Symbol.Map.of_alist_exn
    [ ( aapl
      , { Fundamental_oracle.Config.initial_price_cents = fair_value_cents
        ; volatility_cents_per_sec = 0.0
        ; mean_reversion_strength = 0.0
        ; tick_interval = Time_ns.Span.of_sec 1.0
        } )
    ]
;;

(* Build a runtime around the market maker with mock submit/cancel closures
   that record every request / cancellation. The bot's [submit]/[cancel]
   dispatch here instead of over a real RPC. *)
let make_recording_bot config =
  let submitted = ref [] in
  let cancelled = ref [] in
  let submit request =
    submitted := request :: !submitted;
    return (Ok ())
  in
  let cancel client_order_id =
    cancelled := client_order_id :: !cancelled;
    return (Ok ())
  in
  let oracle = Fundamental_oracle.create oracle_config ~seed:42 in
  let bot =
    Bot_runtime.create
      (module Market_maker_bot)
      config
      ~participant:alice
      ~oracle
      ~rng:(Splittable_random.of_int 7)
      ~submit
      ~cancel
      ~tick_interval:(Time_ns.Span.of_sec 1.0)
  in
  bot, submitted, cancelled
;;

let config () =
  Market_maker_bot.Config.create
    ~symbols:[ aapl ]
    ~size_per_level:10
    ~num_levels:2
    ~inventory_skew_cents_per_share:2
    ~half_spread_cents:10
    ~min_half_spread_cents:10
    ~max_spread_cents:100_000
;;

let print_submitted submitted =
  List.iter (List.rev !submitted) ~f:(fun (req : Order.Request.t) ->
    printf
      !"%{Side} %d@%{Price#dollar}\n"
      req.side
      (Size.to_int req.size)
      req.price)
;;

let print_cancelled cancelled =
  (* [reseed] cancels in [Hashtbl.keys] order, which is unspecified; sort so
     the expectation is stable. *)
  let cids = List.sort ~compare:Client_order_id.compare !cancelled in
  printf "cancelled %d order(s):\n" (List.length cids);
  List.iter cids ~f:(fun cid -> printf !"  %{Client_order_id}\n" cid)
;;

(* Feed the runtime an [Order_accept] for every request the bot has
   submitted, so the bot's internal [resting_orders] table is populated (that
   is what a real exchange would echo back, and what [reseed] later cancels). *)
let accept_all bot submitted =
  Deferred.List.iter
    ~how:`Sequential
    (List.rev !submitted)
    ~f:(fun request ->
      Bot_runtime.feed_event
        bot
        (Order_accept
           { order_id = Order_id.For_testing.of_int 0
           ; participant = alice
           ; request
           }))
;;

let%expect_test "on_start posts a symmetric ladder around fair value" =
  let config = config () in
  let bot, submitted, _cancelled = make_recording_bot config in
  let%bind () =
    Market_maker_bot.on_start config (Bot_runtime.For_testing.context_of bot)
  in
  print_submitted submitted;
  (* fair = $150.00, half_spread = 10c, num_levels = 2. Level [l] quotes at
     offset [half_spread + l]: bids at 14990/14989, asks at 15010/15011. *)
  [%expect
    {|
    BUY 10@$149.90
    SELL 10@$150.10
    BUY 10@$149.89
    SELL 10@$150.11
    |}];
  return ()
;;

let%expect_test "a fill cancels the ladder and re-quotes skewed by inventory"
  =
  let config = config () in
  let bot, submitted, cancelled = make_recording_bot config in
  let context = Bot_runtime.For_testing.context_of bot in
  let%bind () = Market_maker_bot.on_start config context in
  (* Capture the initial ladder so the fill below can reference the id of one
     of the bot's own resting bids. *)
  let ladder = List.rev !submitted in
  let lifted_bid =
    List.find_exn ladder ~f:(fun (r : Order.Request.t) ->
      Side.equal r.side Buy)
  in
  (* Echo the initial ladder back as acceptances so the bot is tracking four
     resting orders that it can later cancel. *)
  let%bind () = accept_all bot submitted in
  (* The maker only re-quotes after a fill if it has seen a healthy market
     spread. Feed a BBO with a 20c spread: half-spread stays at 10c (its
     floor) and the market is well inside [max_spread_cents], so [market_ok]
     holds. Inventory is still 0 here, so this matches the resting ladder and
     does not itself trigger a re-quote. *)
  let%bind () =
    Bot_runtime.feed_event
      bot
      (Best_bid_offer_update
         { symbol = aapl
         ; bbo =
             { bid =
                 Some
                   { price = Price.of_int_cents (fair_value_cents - 10)
                   ; size = Size.of_int 10
                   }
             ; ask =
                 Some
                   { price = Price.of_int_cents (fair_value_cents + 10)
                   ; size = Size.of_int 10
                   }
             }
         })
  in
  (* Reset the recorders so the second phase shows only the reaction to the
     fill. *)
  submitted := [];
  cancelled := [];
  (* Bob lifts the bot's resting bid in full: bob is the aggressive seller,
     the bot is the resting buyer. The bot's inventory goes to +10 (long) and
     that bid, now fully filled, drops out of its working set -- leaving
     three resting orders for the re-quote to cancel. Bob's aggressor id is
     irrelevant here (the bot keys off the resting side, which is its own). *)
  let bob_generator = Client_order_id.Generator.create () in
  let%bind () =
    Bot_runtime.feed_event
      bot
      (Fill
         { fill_id = 1
         ; symbol = aapl
         ; price = lifted_bid.price
         ; size = Size.of_int 10
         ; aggressor_order_id = Order_id.For_testing.of_int 100
         ; aggressor_participant = bob
         ; aggressor_side = Sell
         ; resting_order_id = Order_id.For_testing.of_int 101
         ; resting_participant = alice
         ; aggressor_client_order_id =
             Client_order_id.Generator.next bob_generator
         ; resting_client_order_id = lifted_bid.client_order_id
         })
  in
  print_cancelled cancelled;
  print_submitted submitted;
  (* Long +10 with skew 2c/share shifts the centre down by 20c to $149.80.
     The ladder is symmetric around that new centre: bids 14970/14969, asks
     14990/14991. *)
  [%expect
    {|
    cancelled 3 order(s):
      2
      3
      4
    BUY 10@$149.70
    SELL 10@$149.90
    BUY 10@$149.69
    SELL 10@$149.91
    |}];
  return ()
;;
