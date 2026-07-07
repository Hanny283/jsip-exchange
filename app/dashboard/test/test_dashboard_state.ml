open! Core
open Jsip_types
module Recent_samples = Jsip_dashboard_protocol.Recent_samples

(* Everything below is built by hand — timestamps count seconds from the
   epoch and histograms record known spans — so the views' numbers can be
   checked against the arithmetic in the expectations. Nothing reads the
   clock. *)

let histogram_of spans =
  let histogram = Span_histogram.create () in
  List.iter spans ~f:(Span_histogram.record histogram);
  histogram
;;

let alice = Participant.of_string "Alice"
let bob = Participant.of_string "Bob"
let aapl = Symbol.of_string "AAPL"
let msft = Symbol.of_string "MSFT"

let participant_stats ~orders ~cancels ~resting
  : Exchange_stats.Participant_stats.t
  =
  { orders_submitted = orders
  ; cancels_submitted = cancels
  ; resting_orders = resting
  }
;;

let level ~cents ~size : Level.t =
  { price = Price.of_int_cents cents; size = Size.of_int size }
;;

let book ?bid ?ask ~bid_size ~bid_orders ~ask_size ~ask_orders ()
  : Exchange_stats.Book_depth.t
  =
  { bbo = { bid; ask }
  ; bids = { total_size = Size.of_int bid_size; order_count = bid_orders }
  ; asks = { total_size = Size.of_int ask_size; order_count = ask_orders }
  }
;;

(* One snapshot, [at_s] seconds after the epoch. Only the fields a test cares
   about need to be passed. *)
let sample
  ?(live_words = 0)
  ?(submit_spans = [])
  ?(cancel_spans = [])
  ?(request_queue = 0)
  ?(audit_subscribers = [])
  ?(market_data_subscribers = [])
  ?(sessions = [])
  ?(stats_subscribers = [])
  ?(participants = [])
  ?(books = [])
  ?(iterations = 0)
  ?(gap_spans = [])
  ~seq
  ~at_s
  ()
  : Exchange_stats.t
  =
  { seq
  ; sampled_at = Time_ns.add Time_ns.epoch (Time_ns.Span.of_int_sec at_s)
  ; gc =
      { live_words
      ; heap_words = live_words * 2
      ; minor_collections = 0
      ; major_collections = 0
      ; promoted_words = 0
      ; compactions = 0
      }
  ; latencies =
      { submit = histogram_of submit_spans
      ; cancel = histogram_of cancel_spans
      }
  ; pipes =
      { request_queue
      ; audit_subscribers
      ; market_data_subscribers
      ; sessions
      ; stats_subscribers
      }
  ; participants
  ; books
  ; loop = { iterations; gap = histogram_of gap_spans }
  }
;;

(* A response whose [latest_seq] defaults to the last sample's [seq] (i.e.
   the server has nothing newer than what it is sending). *)
let response ?latest_seq samples : Recent_samples.Response.t =
  let latest_seq =
    match latest_seq with
    | Some _ as latest -> latest
    | None ->
      (match List.last samples with
       | None -> None
       | Some (sample : Exchange_stats.t) -> Some sample.seq)
  in
  { samples; latest_seq }
;;

let feed state samples =
  Dashboard_state.handle_response state (response samples)
;;

let show_cursor state =
  print_s
    [%message
      ""
        ~latest_seq:(Dashboard_state.latest_seq state : int option)
        ~sample_count:(Dashboard_state.sample_count state : int)]
;;

let window_2min = Time_ns.Span.of_int_sec 120

let%expect_test "responses append and the cursor skips duplicates" =
  let state = Dashboard_state.create ~window:window_2min in
  show_cursor state;
  [%expect {| ((latest_seq ()) (sample_count 0)) |}];
  let state =
    feed state [ sample ~seq:1 ~at_s:0 (); sample ~seq:2 ~at_s:1 () ]
  in
  show_cursor state;
  [%expect {| ((latest_seq (2)) (sample_count 2)) |}];
  (* Overlapping response: seq 2 is already held and is ignored. *)
  let state =
    feed state [ sample ~seq:2 ~at_s:1 (); sample ~seq:3 ~at_s:2 () ]
  in
  show_cursor state;
  [%expect {| ((latest_seq (3)) (sample_count 3)) |}];
  (* An empty response (nothing new buffered) changes nothing. *)
  let state = feed state [] in
  show_cursor state;
  [%expect {| ((latest_seq (3)) (sample_count 3)) |}]
;;

let%expect_test "samples older than the window are evicted relative to the \
                 newest sample"
  =
  let state = Dashboard_state.create ~window:(Time_ns.Span.of_int_sec 10) in
  let state =
    feed
      state
      [ sample ~seq:1 ~at_s:0 ()
      ; sample ~seq:2 ~at_s:5 ()
      ; sample ~seq:3 ~at_s:25 ()
      ; sample ~seq:4 ~at_s:30 ()
      ]
  in
  (* Newest is at 30s, so the horizon is 20s: the samples at 0s and 5s fall
     out; 25s (age 5s) and 30s survive. *)
  show_cursor state;
  [%expect {| ((latest_seq (4)) (sample_count 2)) |}]
;;

let%expect_test "a regressed latest_seq resets the window (restart)" =
  let state = Dashboard_state.create ~window:window_2min in
  let state =
    feed
      state
      [ sample ~seq:3 ~at_s:0 ()
      ; sample ~seq:4 ~at_s:1 ()
      ; sample ~seq:5 ~at_s:2 ()
      ]
  in
  show_cursor state;
  [%expect {| ((latest_seq (5)) (sample_count 3)) |}];
  (* The server restarted: numbering began again below our cursor. The old
     window is discarded, not merged. *)
  let state = feed state [ sample ~seq:2 ~at_s:100 () ] in
  show_cursor state;
  [%expect {| ((latest_seq (2)) (sample_count 1)) |}]
;;

let%expect_test "memory view: 60s slice, points, and growth sign" =
  let empty = Dashboard_state.create ~window:window_2min in
  print_s
    [%sexp
      (Dashboard_state.memory_view empty : Dashboard_state.Memory_view.t)];
  [%expect {| ((points ()) (live_words ()) (growth_words_per_sec ())) |}];
  (* Growing heap. The sample at 0s is outside the 60s slice ending at the
     newest sample (110s), so points start at 50s, and growth is
     (12000 - 6000) / 60s = 100 words/s. *)
  let growing =
    feed
      (Dashboard_state.create ~window:(Time_ns.Span.of_int_sec 200))
      [ sample ~seq:1 ~at_s:0 ~live_words:1_000 ()
      ; sample ~seq:2 ~at_s:50 ~live_words:6_000 ()
      ; sample ~seq:3 ~at_s:100 ~live_words:9_000 ()
      ; sample ~seq:4 ~at_s:110 ~live_words:12_000 ()
      ]
  in
  print_s
    [%sexp
      (Dashboard_state.memory_view growing : Dashboard_state.Memory_view.t)];
  [%expect
    {|
    ((points (6000 9000 12000)) (live_words (12000))
     (growth_words_per_sec (100)))
    |}];
  (* Shrinking heap: (2000 - 5000) / 10s = -300 words/s. *)
  let shrinking =
    feed
      empty
      [ sample ~seq:1 ~at_s:0 ~live_words:5_000 ()
      ; sample ~seq:2 ~at_s:10 ~live_words:2_000 ()
      ]
  in
  print_s
    [%sexp
      (Dashboard_state.memory_view shrinking : Dashboard_state.Memory_view.t)];
  [%expect
    {| ((points (5000 2000)) (live_words (2000)) (growth_words_per_sec (-300))) |}]
;;

let%expect_test "latency views: window-merged percentiles and labeled \
                 buckets"
  =
  let state =
    feed
      (Dashboard_state.create ~window:window_2min)
      [ sample
          ~seq:1
          ~at_s:0
          ~submit_spans:
            [ Time_ns.Span.of_int_ns 500
            ; Time_ns.Span.of_int_ns 1_500
            ; Time_ns.Span.of_int_ns 3_000
            ]
          ()
      ; sample
          ~seq:2
          ~at_s:1
          ~submit_spans:
            [ Time_ns.Span.of_int_ns 10_000; Time_ns.Span.of_int_sec 20 ]
          ()
      ]
  in
  (* Five observations merged across both samples: with total 5, p50 needs
     cumulative count 3 (the 2us-4us bucket, upper bound 4us) and p90/p99
     need all 5, landing in the overflow bucket, which reports the last
     boundary. *)
  print_s
    [%sexp
      (Dashboard_state.submit_latency_view state
       : Dashboard_state.Latency_view.t)];
  [%expect
    {|
    ((p50 (4us)) (p90 (16.777216s)) (p99 (16.777216s))
     (buckets ((<1us 1) (1us-2us 1) (2us-4us 1) (8us-16us 1) (>=16.8s 1)))
     (total 5))
    |}];
  (* No cancels were recorded anywhere in the window. *)
  print_s
    [%sexp
      (Dashboard_state.cancel_latency_view state
       : Dashboard_state.Latency_view.t)];
  [%expect {| ((p50 ()) (p90 ()) (p99 ()) (buckets ()) (total 0)) |}]
;;

let%expect_test "occupancy view: named rows, trends vs ~10s earlier" =
  let state =
    feed
      (Dashboard_state.create ~window:window_2min)
      [ sample
          ~seq:1
          ~at_s:0
          ~request_queue:0
          ~audit_subscribers:[ 100; 50 ]
          ~market_data_subscribers:[ aapl, [ 3 ] ]
          ()
      ; sample
          ~seq:2
          ~at_s:12
          ~request_queue:6
          ~audit_subscribers:[ 100; 30 ]
          ~market_data_subscribers:[ aapl, [ 3 ] ]
          ~sessions:[ alice, 2 ]
          ()
      ]
  in
  (* Versus the sample 12s earlier: request-queue grew 0 -> 6, past the
     absolute step of 5 => Rising; audit[0] is unchanged => Flat; audit[1]
     fell 50 -> 30, past the 20% band (10) => Falling; the session pipe did
     not exist then => Flat. *)
  print_s
    [%sexp
      (Dashboard_state.occupancy_view state
       : Dashboard_state.Occupancy_view.t)];
  [%expect
    {|
    (((name request-queue) (length 6) (trend Rising))
     ((name audit[0]) (length 100) (trend Flat))
     ((name audit[1]) (length 30) (trend Falling))
     ((name md:AAPL[0]) (length 3) (trend Flat))
     ((name session:Alice) (length 2) (trend Flat)))
    |}];
  (* When the window is shorter than the 10s lookback, trends compare against
     the oldest sample instead. *)
  let short =
    feed
      (Dashboard_state.create ~window:window_2min)
      [ sample ~seq:1 ~at_s:0 ~request_queue:0 ()
      ; sample ~seq:2 ~at_s:5 ~request_queue:20 ()
      ]
  in
  print_s
    [%sexp
      (Dashboard_state.occupancy_view short
       : Dashboard_state.Occupancy_view.t)];
  [%expect {| (((name request-queue) (length 20) (trend Rising))) |}]
;;

let%expect_test "participants view: mean rates over trailing samples, \
                 resting from newest"
  =
  let state =
    feed
      (Dashboard_state.create ~window:window_2min)
      [ sample
          ~seq:1
          ~at_s:0
          ~participants:
            [ alice, participant_stats ~orders:2 ~cancels:0 ~resting:1 ]
          ()
      ; sample
          ~seq:2
          ~at_s:1
          ~participants:
            [ alice, participant_stats ~orders:4 ~cancels:1 ~resting:2 ]
          ()
      ; sample
          ~seq:3
          ~at_s:2
          ~participants:
            [ alice, participant_stats ~orders:6 ~cancels:2 ~resting:3
            ; bob, participant_stats ~orders:3 ~cancels:0 ~resting:7
            ]
          ()
      ]
  in
  (* Alice: (2+4+6)/3 = 2 orders/s... times three intervals => 4; Bob appears
     in one of the three intervals, so (0+0+3)/3 = 1. Resting counts come
     from the newest sample only. *)
  print_s
    [%sexp
      (Dashboard_state.participants_view state
       : Dashboard_state.Participants_view.t)];
  [%expect
    {|
    (((participant Alice) (orders_per_sec 4) (cancels_per_sec 1)
      (resting_orders 3))
     ((participant Bob) (orders_per_sec 1) (cancels_per_sec 0)
      (resting_orders 7)))
    |}];
  (* Rates use at most the last 10 samples: 12 samples where the first two
     saw 100 orders and the last ten saw 10 average to exactly 10. *)
  let twelve =
    feed
      (Dashboard_state.create ~window:window_2min)
      (List.init 12 ~f:(fun i ->
         let orders = match i < 2 with true -> 100 | false -> 10 in
         sample
           ~seq:(i + 1)
           ~at_s:i
           ~participants:
             [ alice, participant_stats ~orders ~cancels:0 ~resting:0 ]
           ()))
  in
  print_s
    [%sexp
      (Dashboard_state.participants_view twelve
       : Dashboard_state.Participants_view.t)];
  [%expect
    {|
    (((participant Alice) (orders_per_sec 10) (cancels_per_sec 0)
      (resting_orders 0)))
    |}]
;;

let%expect_test "depth view: present, quote-less, and absent symbols" =
  let empty = Dashboard_state.create ~window:window_2min in
  print_s
    [%sexp
      (Dashboard_state.depth_view empty ~symbol:aapl
       : Dashboard_state.Depth_view.t option)];
  [%expect {| () |}];
  let state =
    feed
      empty
      [ sample
          ~seq:1
          ~at_s:0
          ~books:
            [ ( aapl
              , book
                  ~bid:(level ~cents:9_950 ~size:10)
                  ~ask:(level ~cents:10_050 ~size:5)
                  ~bid_size:10
                  ~bid_orders:1
                  ~ask_size:5
                  ~ask_orders:2
                  () )
            ; ( msft
              , book ~bid_size:0 ~bid_orders:0 ~ask_size:0 ~ask_orders:0 () )
            ]
          ()
      ]
  in
  print_s [%sexp (Dashboard_state.symbols state : Symbol.t list)];
  [%expect {| (AAPL MSFT) |}];
  print_s
    [%sexp
      (Dashboard_state.depth_view state ~symbol:aapl
       : Dashboard_state.Depth_view.t option)];
  [%expect
    {|
    (((bbo (((bid (((price 9950) (size 10)))) (ask (((price 10050) (size 5)))))))
      (bid_size 10) (bid_orders 1) (ask_size 5) (ask_orders 2)))
    |}];
  (* MSFT's book exists but holds no orders at all: [bbo] is [None] so the
     pane can render a dash. *)
  print_s
    [%sexp
      (Dashboard_state.depth_view state ~symbol:msft
       : Dashboard_state.Depth_view.t option)];
  [%expect
    {|
    (((bbo ()) (bid_size 0) (bid_orders 0) (ask_size 0) (ask_orders 0)))
    |}];
  print_s
    [%sexp
      (Dashboard_state.depth_view state ~symbol:(Symbol.of_string "GOOG")
       : Dashboard_state.Depth_view.t option)];
  [%expect {| () |}]
;;

let%expect_test "loop view: gap percentiles, worst-gap points, iteration \
                 rate"
  =
  let state =
    feed
      (Dashboard_state.create ~window:window_2min)
      [ sample
          ~seq:1
          ~at_s:0
          ~iterations:100
          ~gap_spans:[ Time_ns.Span.of_int_ms 1; Time_ns.Span.of_int_ms 3 ]
          ()
      ; sample ~seq:2 ~at_s:1 ~iterations:90 ()
      ; sample
          ~seq:3
          ~at_s:2
          ~iterations:110
          ~gap_spans:[ Time_ns.Span.of_int_sec 20 ]
          ()
      ]
  in
  (* Worst-gap points, oldest first: 3ms lands in the 2.048ms-4.096ms bucket
     (upper bound 0.004096s); the gap-less sample reports 0; 20s overflows
     and reports the last boundary, 16.777216s. Iterations average
     (100+90+110)/3 = 100/s. *)
  print_s
    [%sexp (Dashboard_state.loop_view state : Dashboard_state.Loop_view.t)];
  [%expect
    {|
    ((p50 (4.096ms)) (p99 (16.777216s)) (max_gap_points (0.004096 0 16.777216))
     (iterations_per_sec (100)))
    |}]
;;
