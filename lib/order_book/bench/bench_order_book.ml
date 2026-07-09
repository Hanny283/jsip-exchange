(** Benchmarks for the order book and matching engine.

    Run with: dune exec lib/order_book/bench/bench_order_book.exe -- -ascii
    -quota 5

    These benchmarks measure the core operations of the exchange and are
    designed to give you meaningful feedback on the performance of the system
    and the effect of any optimizations you make.

    {2 How to read the results}

    Core_bench reports time per operation in nanoseconds. Lower is better.
    Focus on:
    - [find_match]: the hot path — called on every incoming order
    - [submit_ioc_cross]: end-to-end order submission with a fill
    - [add/remove]: book mutation performance
    - [best_price]: how fast you can query the BBO

    {2 Tips for meaningful benchmarks}

    {ul
     {- Use [-quota 5] or higher for stable results (5 seconds per bench). }
     {- Run on a quiet machine (no heavy background processes). }
     {- Compare before/after by saving results:

       {v
          dune exec lib/order_book/bench/bench_order_book.exe -- -ascii -quota 5 > before.txt
          # ... make your changes ...
          dune exec lib/order_book/bench/bench_order_book.exe -- -ascii -quota 5 > after.txt
          diff before.txt after.txt
       v}
    }
    } *)

open! Core
open Core_bench
open Jsip_types
open Jsip_order_book

(* ---------------------------------------------------------------- *)
(* Setup helpers *)
(* ---------------------------------------------------------------- *)

let aapl = Symbol.of_string "AAPL"
let alice = Participant.of_string "Alice"
let bob = Participant.of_string "Bob"

(** Build a book with [n] resting sell orders at prices 1..n (in cents). This
    gives a realistic spread of prices for benchmarking find_match and
    best_price queries. *)
let book_with_n_asks ?(min_price = 10_000) n =
  let book = Order_book.create aapl in
  let gen = Order_id.Generator.create () in
  for i = 1 to n do
    let order =
      Order.create
        { symbol = aapl
        ; side = Sell
        ; price = Price.of_int_cents (min_price + i)
        ; size = Size.of_int 100
        ; time_in_force = Day
        ; client_order_id = Client_order_id.of_string (Int.to_string i)
        }
        ~order_id:(Order_id.Generator.next gen)
        ~participant:bob
    in
    Order_book.add book order
  done;
  book, gen
;;

(** Build a book with [n] resting sell orders all at the SAME price. Unlike
    {!book_with_n_asks}, which spreads orders across distinct prices (one
    order per level), this stacks the whole book into a single price level.
    That is the case [snapshot] must aggregate — summing [n] remaining sizes
    into one [Level.t] — so it's what makes the aggregation cost visible. *)
let book_with_n_asks_same_price ?(price = 15_000) n =
  let book = Order_book.create aapl in
  let gen = Order_id.Generator.create () in
  for i = 1 to n do
    let order =
      Order.create
        { symbol = aapl
        ; side = Sell
        ; price = Price.of_int_cents price
        ; size = Size.of_int 100
        ; time_in_force = Day
        ; client_order_id = Client_order_id.of_string (Int.to_string i)
        }
        ~order_id:(Order_id.Generator.next gen)
        ~participant:bob
    in
    Order_book.add book order
  done;
  book
;;

(** Build a matching engine with [n] resting sells on AAPL. *)
let engine_with_n_asks ?(min_price = 10_000) n =
  let engine = Matching_engine.create [ aapl ] in
  for i = 1 to n do
    ignore
      (Matching_engine.submit
         engine
         { symbol = aapl
         ; side = Sell
         ; price = Price.of_int_cents (min_price + i)
         ; size = Size.of_int 100
         ; time_in_force = Day
         ; client_order_id = Client_order_id.of_string (Int.to_string i)
         }
         ~participant:bob
       : Exchange_event.t list)
  done;
  engine
;;

(* ---------------------------------------------------------------- *)
(* Order_book micro-benchmarks *)
(* ---------------------------------------------------------------- *)

let bench_find_match ~n =
  let min_price = 10_000 in
  let book, gen = book_with_n_asks ~min_price n in
  (* Incoming buy at a price that matches the best ask *)
  let incoming =
    Order.create
      { symbol = aapl
      ; side = Buy
      ; price = Price.of_int_cents (min_price + n)
      ; size = Size.of_int 100
      ; time_in_force = Ioc
      ; client_order_id = Client_order_id.of_string (Int.to_string 1)
      }
      ~order_id:(Order_id.Generator.next gen)
      ~participant:alice
  in
  Bench.Test.create ~name:[%string "find_match (n=%{n#Int})"] (fun () ->
    ignore (Order_book.find_match book incoming : Order.t option))
;;

let bench_find_match_no_cross ~n =
  let min_price = 10_000 in
  let book, gen = book_with_n_asks ~min_price n in
  (* Incoming buy at a price below all asks — no match possible *)
  let incoming =
    Order.create
      { symbol = aapl
      ; side = Buy
      ; price = Price.of_int_cents (min_price - 1)
      ; size = Size.of_int 100
      ; time_in_force = Ioc
      ; client_order_id = Client_order_id.of_string (Int.to_string 1)
      }
      ~order_id:(Order_id.Generator.next gen)
      ~participant:alice
  in
  Bench.Test.create ~name:[%string "find_match_miss (n=%{n#Int})"] (fun () ->
    ignore (Order_book.find_match book incoming : Order.t option))
;;

let bench_best_bid_offer ~n =
  let book, _gen = book_with_n_asks n in
  Bench.Test.create ~name:[%string "best_bid_offer (n=%{n#Int})"] (fun () ->
    ignore (Order_book.best_bid_offer book : Bbo.t))
;;

let bench_add_remove ~n =
  (* Pre-build the book, then measure add+remove cycle *)
  let min_price = 10_000 in
  let book, gen = book_with_n_asks ~min_price n in
  let order =
    Order.create
      { symbol = aapl
      ; side = Sell
      ; price = Price.of_int_cents (min_price + 500)
      ; size = Size.of_int 100
      ; time_in_force = Day
      ; client_order_id = Client_order_id.of_string (Int.to_string 1)
      }
      ~order_id:(Order_id.Generator.next gen)
      ~participant:alice
  in
  let oid = Order.order_id order in
  Bench.Test.create ~name:[%string "add+remove (n=%{n#Int})"] (fun () ->
    Order_book.add book order;
    Order_book.remove book oid)
;;

(* ---------------------------------------------------------------- *)
(* Snapshot benchmarks *)
(* ---------------------------------------------------------------- *)

let bench_snapshot ~n =
  (* Time a full-book snapshot over [n] orders stacked at one price. This
     exercises the aggregation path in [snapshot_side]: [n] orders collapse
     into a single [Level.t] whose size is the sum of their remaining sizes. *)
  let book = book_with_n_asks_same_price n in
  Bench.Test.create ~name:[%string "snapshot (n=%{n#Int})"] (fun () ->
    ignore (Order_book.snapshot book : Book.t))
;;

(* ---------------------------------------------------------------- *)
(* Matching engine end-to-end benchmarks *)
(* ---------------------------------------------------------------- *)

let bench_submit_ioc_cross ~n =
  (* Measure submitting an IOC order that crosses the best ask. This is the
     most common hot path: order in, fill out. We re-seed a resting order
     after each iteration to keep the book state consistent. *)
  let min_price = 10_000 in
  let max_price = 20_000 in
  let engine = engine_with_n_asks ~min_price n in
  let next_price = ref (min_price + 1) in
  Bench.Test.create
    ~name:[%string "submit_ioc_cross (n=%{n#Int})"]
    (fun () ->
       let events =
         Matching_engine.submit
           engine
           { symbol = aapl
           ; side = Buy
           ; price = Price.of_int_cents max_price
           ; size = Size.of_int 100
           ; time_in_force = Ioc
           ; client_order_id = Client_order_id.of_string (Int.to_string 1)
           }
           ~participant:alice
       in
       ignore (events : Exchange_event.t list);
       (* Re-seed: add back a resting sell to replace the one we consumed *)
       ignore
         (Matching_engine.submit
            engine
            { symbol = aapl
            ; side = Sell
            ; price = Price.of_int_cents !next_price
            ; size = Size.of_int 100
            ; time_in_force = Day
            ; client_order_id = Client_order_id.of_string (Int.to_string 1)
            }
            ~participant:bob
          : Exchange_event.t list);
       next_price := !next_price + 1;
       if !next_price > max_price then next_price := min_price + 1)
;;

let bench_submit_ioc_no_match ~n =
  let min_price = 10_000 in
  let engine = engine_with_n_asks ~min_price n in
  Bench.Test.create ~name:[%string "submit_ioc_miss (n=%{n#Int})"] (fun () ->
    ignore
      (Matching_engine.submit
         engine
         { symbol = aapl
         ; side = Buy
         ; price = Price.of_int_cents (min_price - 1)
         ; size = Size.of_int 100
         ; time_in_force = Ioc
         ; client_order_id = Client_order_id.of_string (Int.to_string 1)
         }
         ~participant:alice
       : Exchange_event.t list))
;;

let bench_submit_sweep ~n =
  (* Measure an aggressive order that sweeps through the entire book.
     Re-seeds the book after each sweep. This is worst-case: every resting
     order is visited and filled. *)
  let engine = ref (engine_with_n_asks n) in
  Bench.Test.create ~name:[%string "submit_sweep_%{n#Int}_levels"] (fun () ->
    ignore
      (Matching_engine.submit
         !engine
         { symbol = aapl
         ; side = Buy
         ; price = Price.of_int_cents 99_999
         ; size = Size.of_int (n * 100)
         ; time_in_force = Ioc
         ; client_order_id = Client_order_id.of_string (Int.to_string 1)
         }
         ~participant:alice
       : Exchange_event.t list);
    (* Re-seed entire book *)
    engine := engine_with_n_asks n)
;;

(* ---------------------------------------------------------------- *)
(* Allocation measurement *)
(* ---------------------------------------------------------------- *)

let bench_find_match_alloc ~n =
  let min_price = 10_000 in
  let book, gen = book_with_n_asks ~min_price n in
  let incoming =
    Order.create
      { symbol = aapl
      ; side = Buy
      ; price = Price.of_int_cents (min_price + n)
      ; size = Size.of_int 100
      ; time_in_force = Ioc
      ; client_order_id = Client_order_id.of_string (Int.to_string 1)
      }
      ~order_id:(Order_id.Generator.next gen)
      ~participant:alice
  in
  (* Measure minor-heap allocations *)
  let measure_alloc f =
    Gc.compact ();
    let before = (Gc.stat ()).minor_words in
    for _ = 1 to 1000 do
      f ()
    done;
    let after = (Gc.stat ()).minor_words in
    (after -. before) /. 1000.0
  in
  let words_per_call =
    measure_alloc (fun () ->
      ignore (Order_book.find_match book incoming : Order.t option))
  in
  Bench.Test.create
    ~name:
      (sprintf "find_match_alloc (n=%d, %.1f words/call)" n words_per_call)
    (fun () -> ignore (Order_book.find_match book incoming : Order.t option))
;;

(* ---------------------------------------------------------------- *)
(* Symbol lookup (Matching_engine.book) benchmarks *)
(* ---------------------------------------------------------------- *)

(* The engine holds one order book per symbol and resolves a symbol to its
   book on every operation. [book] is the pure lookup path — no matching work
   — so it isolates that resolution cost. [submit]/[cancel] resolve a symbol
   too, but then do matching, which would bury the lookup; that's why we
   bench [book] alone. Vary the number of symbols the engine trades to see
   how the lookup scales: with a tree keyed by the symbol string it's
   O(log n) string comparisons; the goal of the upcoming interning change is
   to make it O(1). *)

let symbol_name i = Symbol.of_string [%string "SYM%{i#Int}"]

let engine_with_n_symbols n =
  Matching_engine.create (List.init n ~f:symbol_name)
;;

let bench_book_lookup ~n =
  let engine = engine_with_n_symbols n in
  (* Resolve a symbol that exists, taken from the middle of the set. Build
     the query with a FRESH [Symbol.of_string] (not the value handed to
     [create]) so the comparison actually walks the string's characters
     instead of short-circuiting on physical equality. *)
  let target = symbol_name (n / 2) in
  Bench.Test.create
    ~name:[%string "book_lookup (symbols=%{n#Int})"]
    (fun () ->
       ignore (Matching_engine.book engine target : Order_book.t option))
;;

(* ---------------------------------------------------------------- *)
(* Main *)
(* ---------------------------------------------------------------- *)

let () =
  let sizes = [ 10; 50; 100; 500 ] in
  let symbol_counts = [ 10; 100; 1_000; 10_000 ] in
  let tests =
    List.concat
      [ (* Order book micro-benchmarks at various sizes *)
        List.map sizes ~f:(fun n -> bench_find_match ~n)
      ; List.map sizes ~f:(fun n -> bench_find_match_no_cross ~n)
      ; List.map sizes ~f:(fun n -> bench_best_bid_offer ~n)
      ; [ bench_add_remove ~n:100 ]
      ; (* Matching engine end-to-end *)
        List.map sizes ~f:(fun n -> bench_submit_ioc_cross ~n)
      ; List.map sizes ~f:(fun n -> bench_submit_ioc_no_match ~n)
      ; List.map [ 10; 50; 100 ] ~f:(fun n -> bench_submit_sweep ~n)
      ; (* Allocation awareness *)
        [ bench_find_match_alloc ~n:100 ]
      ]
  in
  Command_unix.run
    (Command.group
       ~summary:"JSIP order-book benchmarks"
       [ "existing", Bench.make_command tests
       ; ( "snapshot"
         , Bench.make_command
             (List.map sizes ~f:(fun n -> bench_snapshot ~n)) )
       ; ( "book-lookup"
         , Bench.make_command
             (List.map symbol_counts ~f:(fun n -> bench_book_lookup ~n)) )
       ])
;;
