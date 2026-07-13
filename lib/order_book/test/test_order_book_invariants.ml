(** Coherence tests for {!Order_book}'s cached best levels.

    The book keeps an O(1) cache of each side's best (price, level queue)
    alongside the authoritative price maps — two copies of one fact, kept in
    sync by the [add]/[remove] code paths. These tests exist so that sync can
    never rot silently: [For_testing.invariant] checks the cache against the
    maps (price equality AND physical queue identity), and the randomized
    workload below calls it after every single operation. Any future mutation
    path that forgets the cache — a bulk end-of-day cancel, say — fails here
    with a minimal, seeded reproduction, not in production with a mispriced
    fill. *)

open! Core
open Jsip_types
open Jsip_order_book
open Jsip_test_harness

let make_order ~gen ~side ~price_cents ~i =
  Order.create
    { symbol = Harness.aapl
    ; side
    ; price = Price.of_int_cents price_cents
    ; size = Size.of_int 100
    ; time_in_force = Day
    ; client_order_id = Client_order_id.of_string (Int.to_string i)
    }
    ~order_id:(Order_id.Generator.next gen)
    ~participant:Harness.alice
;;

(* The best the cache claims, recomputed the slow, obviously-correct way:
   scan every resting order on the side. *)
let best_by_scan book side =
  Order_book.orders_on_side book side
  |> List.map ~f:Order.price
  |> List.reduce ~f:(fun a b ->
    if Price.is_more_aggressive side ~price:a ~than:b then a else b)
;;

let check book =
  Order_book.For_testing.invariant book;
  List.iter
    Side.[ Buy; Sell ]
    ~f:(fun side ->
      let cached = Order_book.best_price book side in
      let scanned = best_by_scan book side in
      if not ([%equal: Price.t option] cached scanned)
      then
        raise_s
          [%message
            "cached best disagrees with full scan"
              (side : Side.t)
              (cached : Price.t option)
              (scanned : Price.t option)])
;;

let%expect_test "randomized adds and removes keep the cache coherent" =
  (* Both sides at once, prices clustered on few levels (so levels grow deep,
     empty out, and reopen — the transitions that move the best), removals
     targeting random resting orders including the best. 2000 steps x
     invariant-after-every-step; the seed makes failures reproducible. *)
  let book = Order_book.create Harness.aapl in
  let gen = Order_id.Generator.create () in
  let random = Random.State.make [| 42 |] in
  let resting = ref [] in
  for i = 1 to 2_000 do
    let add_one () =
      let side = if Random.State.bool random then Side.Buy else Sell in
      let price_cents =
        (* Bids cluster below 15_000, asks above, so the book stays two-sided
           and uncrossed while both bests keep moving. *)
        match side with
        | Buy -> 14_800 + (Random.State.int random 20 * 10)
        | Sell -> 15_010 + (Random.State.int random 20 * 10)
      in
      let order = make_order ~gen ~side ~price_cents ~i in
      Order_book.add book order;
      resting := Order.order_id order :: !resting
    in
    let remove_one () =
      match !resting with
      | [] -> add_one ()
      | _ ->
        let victim =
          List.nth_exn
            !resting
            (Random.State.int random (List.length !resting))
        in
        Order_book.remove book victim;
        resting
        := List.filter !resting ~f:(fun id -> not (Order_id.( = ) id victim))
    in
    if Random.State.bool random then add_one () else remove_one ();
    check book
  done;
  (* Drain to empty: the caches must come back to None, not point at freed
     levels. *)
  List.iter !resting ~f:(fun id ->
    Order_book.remove book id;
    check book);
  assert (Order_book.is_empty book);
  print_endline "ok";
  [%expect {| ok |}]
;;

let%expect_test "the transitions that move the best, pinned one by one" =
  let book = Order_book.create Harness.aapl in
  let gen = Order_id.Generator.create () in
  let order_at ~side price_cents i = make_order ~gen ~side ~price_cents ~i in
  let show () =
    print_s
      [%message
        ""
          ~best_bid:(Order_book.best_price book Buy : Price.t option)
          ~best_ask:(Order_book.best_price book Sell : Price.t option)]
  in
  (* A better price takes over the cache. *)
  let ask_150_10 = order_at ~side:Sell 15_010 1 in
  let ask_150_00 = order_at ~side:Sell 15_000 2 in
  Order_book.add book ask_150_10;
  check book;
  Order_book.add book ask_150_00;
  check book;
  show ();
  [%expect {| ((best_bid ()) (best_ask (15000))) |}];
  (* A second order AT the best joins the cached queue (no cache motion);
     removing the first promotes the second within the level. *)
  let ask_150_00_b = order_at ~side:Sell 15_000 3 in
  Order_book.add book ask_150_00_b;
  check book;
  Order_book.remove book (Order.order_id ask_150_00);
  check book;
  show ();
  [%expect {| ((best_bid ()) (best_ask (15000))) |}];
  (* Emptying the best level entirely falls back to the next level — the one
     recompute path. *)
  Order_book.remove book (Order.order_id ask_150_00_b);
  check book;
  show ();
  [%expect {| ((best_bid ()) (best_ask (15010))) |}];
  (* Removing a non-best level leaves the best untouched. *)
  let ask_150_20 = order_at ~side:Sell 15_020 4 in
  Order_book.add book ask_150_20;
  check book;
  Order_book.remove book (Order.order_id ask_150_20);
  check book;
  show ();
  [%expect {| ((best_bid ()) (best_ask (15010))) |}];
  (* Draining the side empties the cache. *)
  Order_book.remove book (Order.order_id ask_150_10);
  check book;
  show ();
  [%expect {| ((best_bid ()) (best_ask ())) |}]
;;

let%expect_test "engine-level workload keeps books coherent through fills" =
  (* Partial fills, full fills, IOC remainders, and self-trade-prevention
     cancels all mutate the book through the engine's paths rather than raw
     add/remove — run a burst of random engine traffic and check the book
     after every submit. *)
  let t = Harness.create () in
  let book () =
    Option.value_exn (Matching_engine.book (Harness.engine t) Harness.aapl)
  in
  let random = Random.State.make [| 7 |] in
  for _ = 1 to 500 do
    let side = if Random.State.bool random then Side.Buy else Sell in
    let price_cents = 14_950 + (Random.State.int random 12 * 10) in
    let size = 10 + (Random.State.int random 4 * 45) in
    let time_in_force : Time_in_force.t =
      if Random.State.bool random then Day else Ioc
    in
    let participant =
      if Random.State.bool random then Harness.alice else Harness.bob
    in
    let request =
      match side with
      | Buy -> Harness.buy ~price_cents ~size ~time_in_force ()
      | Sell -> Harness.sell ~price_cents ~size ~time_in_force ()
    in
    ignore
      (Harness.submit_quiet ~participant t request : Exchange_event.t list);
    Order_book.For_testing.invariant (book ())
  done;
  print_endline "ok";
  [%expect {| ok |}]
;;
