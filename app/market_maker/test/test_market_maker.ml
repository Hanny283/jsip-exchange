(** Tests for the market maker. *)

open! Core
open! Async
open Jsip_types
open Jsip_test_harness
open Jsip_market_maker
open E2e_helpers

let default_config : Market_maker.Config.t =
  { participant = Harness.market_maker
  ; symbol = Harness.aapl
  ; fair_value_cents = 15000
  ; half_spread_cents = 10
  ; size_per_level = 100
  ; num_levels = 3
  ; inventory_skew_cents_per_share = 1
  }
;;

let%expect_test "seed_book: places symmetric bids and asks around fair value"
  =
  with_server ~symbols:[ Harness.aapl ] (fun ~server:_ ~port ->
    let%bind mm = connect_as ~port Harness.market_maker in
    let%bind () = Market_maker.seed_book default_config (connection mm) in
    [%expect
      {|
      [for MarketMaker] ACCEPTED id=1 AAPL BUY 100@$149.90 DAY
      [for MarketMaker] ACCEPTED id=2 AAPL SELL 100@$150.10 DAY
      [for MarketMaker] ACCEPTED id=3 AAPL BUY 100@$149.89 DAY
      [for MarketMaker] ACCEPTED id=4 AAPL SELL 100@$150.11 DAY
      [for MarketMaker] ACCEPTED id=5 AAPL BUY 100@$149.88 DAY
      [for MarketMaker] ACCEPTED id=6 AAPL SELL 100@$150.12 DAY
      |}];
    return ())
;;

(* --- Unit tests for the dynamic market maker (exercises 2a-2c) ---

   These drive [Market_maker.make] directly with recording [submit] / [cancel]
   closures, so we can push a controlled sequence of session-feed events at the
   bot and inspect exactly what it tracks and what it sends. No live server,
   fully deterministic. *)

type harness =
  { submitted : Order.Request.t list ref
  ; cancelled : Client_order_id.t list ref
  ; outstanding : int Client_order_id.Table.t
  ; inventory : int Symbol.Table.t
  ; post : unit -> unit Deferred.t
  ; handle_event : Exchange_event.t -> unit
  }

let make_recording (config : Market_maker.Config.t) =
  let submitted = ref [] in
  let cancelled = ref [] in
  let submit request =
    submitted := request :: !submitted;
    Deferred.unit
  in
  let cancel client_order_id =
    cancelled := client_order_id :: !cancelled;
    Deferred.unit
  in
  let outstanding, inventory, post, handle_event =
    Market_maker.make config ~submit ~cancel
  in
  { submitted; cancelled; outstanding; inventory; post; handle_event }
;;

let order_id n = Order_id.For_testing.of_int n

(* An [Order_accept] for one of the market maker's own orders. *)
let accept ~(side : Side.t) ~cid ~size : Exchange_event.t =
  Order_accept
    { order_id = order_id 0
    ; request =
        ({ symbol = Harness.aapl
         ; participant = Harness.market_maker
         ; side
         ; price = Price.of_int_cents 15000
         ; size = Size.of_int size
         ; time_in_force = Day
         ; client_order_id = cid
         }
         : Order.Request.t)
    }
;;

(* A [Fill] where the market maker is the resting party (its quote was hit by
   [Harness.alice] crossing from the other side). [mm_side] is the market
   maker's own side: [Buy] when its bid is hit, [Sell] when its ask is lifted. *)
let fill_resting ~(mm_side : Side.t) ~cid ~size : Exchange_event.t =
  Fill
    { fill_id = 0
    ; symbol = Harness.aapl
    ; price = Price.of_int_cents 15000
    ; size = Size.of_int size
    ; aggressor_order_id = order_id 0
    ; aggressor_participant = Harness.alice
    ; aggressor_side = Side.flip mm_side
    ; resting_order_id = order_id 0
    ; resting_participant = Harness.market_maker
    ; aggressor_client_order_id = Client_order_id.of_string "0"
    ; resting_client_order_id = cid
    }
;;

let side_str (s : Side.t) =
  match s with
  | Buy -> "BUY"
  | Sell -> "SELL"
;;

let dollar (price : Price.t) =
  let cents = Price.to_int_cents price in
  sprintf "$%d.%02d" (cents / 100) (Int.abs (cents % 100))
;;

(* Print a set of submitted orders sorted by side then price, so the output is
   independent of the order the bot happened to enqueue them in. *)
let print_ladder (requests : Order.Request.t list) =
  requests
  |> List.sort ~compare:(fun (a : Order.Request.t) (b : Order.Request.t) ->
    [%compare: Side.t * Price.t] (a.side, a.price) (b.side, b.price))
  |> List.iter ~f:(fun (r : Order.Request.t) ->
    printf "%s %d @ %s\n" (side_str r.side) (Size.to_int r.size) (dollar r.price))
;;

let print_state (h : harness) =
  let inventory =
    Option.value (Hashtbl.find h.inventory Harness.aapl) ~default:0
  in
  let outstanding =
    Hashtbl.keys h.outstanding
    |> List.sort ~compare:Client_order_id.compare
    |> List.map ~f:Client_order_id.to_string
    |> String.concat ~sep:", "
  in
  printf "inventory AAPL=%d; outstanding=[%s]\n" inventory outstanding
;;

let%expect_test "2a: fills update inventory and outstanding-order state" =
  let h = make_recording default_config in
  let bid = Client_order_id.of_string "101" in
  let ask = Client_order_id.of_string "102" in
  (* Two of the market maker's orders rest on the book. *)
  h.handle_event (accept ~side:Buy ~cid:bid ~size:100);
  h.handle_event (accept ~side:Sell ~cid:ask ~size:100);
  print_state h;
  [%expect {| inventory AAPL=0; outstanding=[101, 102] |}];
  (* Someone lifts 60 of the ask: the maker (resting seller) goes short 60. The
     ask still has 40 working, so it stays in the outstanding set. *)
  h.handle_event (fill_resting ~mm_side:Sell ~cid:ask ~size:60);
  print_state h;
  [%expect {| inventory AAPL=-60; outstanding=[101, 102] |}];
  (* The remaining 40 of the ask trades: it is fully filled and drops off. *)
  h.handle_event (fill_resting ~mm_side:Sell ~cid:ask ~size:40);
  print_state h;
  [%expect {| inventory AAPL=-100; outstanding=[101] |}];
  (* The bid is hit for 100: the maker (resting buyer) returns to flat. *)
  h.handle_event (fill_resting ~mm_side:Buy ~cid:bid ~size:100);
  print_state h;
  [%expect {| inventory AAPL=0; outstanding=[] |}];
  return ()
;;

let%expect_test "2b: a fill cancels the resting ladder and re-quotes (no skew)" =
  let config = { default_config with inventory_skew_cents_per_share = 0 } in
  let h = make_recording config in
  (* Seed the initial ladder. *)
  let%bind () = h.post () in
  let initial = List.rev !(h.submitted) in
  print_endline "initial ladder:";
  print_ladder initial;
  [%expect
    {|
    initial ladder:
    BUY 100 @ $149.88
    BUY 100 @ $149.89
    BUY 100 @ $149.90
    SELL 100 @ $150.10
    SELL 100 @ $150.11
    SELL 100 @ $150.12
    |}];
  (* The exchange accepts every order; the bot records them as resting. *)
  List.iter initial ~f:(fun req ->
    h.handle_event (Order_accept { order_id = order_id 0; request = req }));
  (* Isolate the activity caused by the next fill. *)
  h.submitted := [];
  (* The best ask is fully lifted. *)
  let filled =
    List.find_exn initial ~f:(fun (r : Order.Request.t) ->
      Side.equal r.side Sell && Price.to_int_cents r.price = 15010)
  in
  h.handle_event
    (fill_resting
       ~mm_side:Sell
       ~cid:filled.client_order_id
       ~size:(Size.to_int filled.size));
  (* Every other resting order is cancelled (the filled one is already gone),
     then a fresh ladder is posted at the same prices, since there's no skew. *)
  let other_cids =
    List.filter_map initial ~f:(fun (r : Order.Request.t) ->
      if Client_order_id.equal r.client_order_id filled.client_order_id
      then None
      else Some r.client_order_id)
    |> Client_order_id.Set.of_list
  in
  let cancelled = Client_order_id.Set.of_list !(h.cancelled) in
  printf
    "cancelled exactly the other resting orders: %b (count=%d)\n"
    (Set.equal other_cids cancelled)
    (Set.length cancelled);
  print_endline "re-quoted ladder:";
  print_ladder (List.rev !(h.submitted));
  [%expect
    {|
    cancelled exactly the other resting orders: true (count=5)
    re-quoted ladder:
    BUY 100 @ $149.88
    BUY 100 @ $149.89
    BUY 100 @ $149.90
    SELL 100 @ $150.10
    SELL 100 @ $150.11
    SELL 100 @ $150.12
    |}];
  return ()
;;

let%expect_test "2c: the re-quoted ladder is skewed by inventory" =
  let config = { default_config with inventory_skew_cents_per_share = 1 } in
  let h = make_recording config in
  let%bind () = h.post () in
  let initial = List.rev !(h.submitted) in
  List.iter initial ~f:(fun req ->
    h.handle_event (Order_accept { order_id = order_id 0; request = req }));
  h.submitted := [];
  (* The best bid is hit for 50: the maker buys, so inventory = +50. At
     1c/share that shifts the fair value down to $149.50 and the whole ladder
     with it. *)
  let filled =
    List.find_exn initial ~f:(fun (r : Order.Request.t) ->
      Side.equal r.side Buy && Price.to_int_cents r.price = 14990)
  in
  h.handle_event (fill_resting ~mm_side:Buy ~cid:filled.client_order_id ~size:50);
  printf
    "inventory AAPL=%d, outstanding count=%d\n"
    (Option.value (Hashtbl.find h.inventory Harness.aapl) ~default:0)
    (Hashtbl.length h.outstanding);
  print_endline "re-quoted ladder:";
  print_ladder (List.rev !(h.submitted));
  [%expect
    {|
    inventory AAPL=50, outstanding count=6
    re-quoted ladder:
    BUY 100 @ $149.38
    BUY 100 @ $149.39
    BUY 100 @ $149.40
    SELL 100 @ $149.60
    SELL 100 @ $149.61
    SELL 100 @ $149.62
    |}];
  return ()
;;

let%expect_test "2c: alternating fills oscillate quotes symmetrically around fair"
  =
  let config = { default_config with inventory_skew_cents_per_share = 1 } in
  let fair = config.fair_value_cents in
  let h = make_recording config in
  let%bind () = h.post () in
  h.submitted := [];
  (* Buy 100 -> long 100 -> the ladder skews down. *)
  h.handle_event
    (fill_resting ~mm_side:Buy ~cid:(Client_order_id.of_string "0") ~size:100);
  let long_ladder = List.rev !(h.submitted) in
  h.submitted := [];
  (* Sell 200 -> net short 100 -> the ladder skews up by the same amount. *)
  h.handle_event
    (fill_resting ~mm_side:Sell ~cid:(Client_order_id.of_string "0") ~size:200);
  let short_ladder = List.rev !(h.submitted) in
  print_endline "long (inventory +100):";
  print_ladder long_ladder;
  print_endline "short (inventory -100):";
  print_ladder short_ladder;
  (* Reflecting the long ladder about the fair value -- each buy at p becomes a
     sell at 2*fair - p and vice versa -- should reproduce the short ladder if
     the skew is symmetric. *)
  let as_pairs ladder =
    List.map ladder ~f:(fun (r : Order.Request.t) ->
      r.side, Price.to_int_cents r.price)
    |> List.sort ~compare:[%compare: Side.t * int]
  in
  let reflected_long =
    List.map long_ladder ~f:(fun (r : Order.Request.t) ->
      Side.flip r.side, (2 * fair) - Price.to_int_cents r.price)
    |> List.sort ~compare:[%compare: Side.t * int]
  in
  printf
    "symmetric around fair: %b\n"
    ([%compare.equal: (Side.t * int) list]
       reflected_long
       (as_pairs short_ladder));
  [%expect
    {|
    long (inventory +100):
    BUY 100 @ $148.88
    BUY 100 @ $148.89
    BUY 100 @ $148.90
    SELL 100 @ $149.10
    SELL 100 @ $149.11
    SELL 100 @ $149.12
    short (inventory -100):
    BUY 100 @ $150.88
    BUY 100 @ $150.89
    BUY 100 @ $150.90
    SELL 100 @ $151.10
    SELL 100 @ $151.11
    SELL 100 @ $151.12
    symmetric around fair: true
    |}];
  return ()
;;
