open! Core
open Jsip_types

let histogram_of spans =
  let histogram = Span_histogram.create () in
  List.iter spans ~f:(Span_histogram.record histogram);
  histogram
;;

(* Pins the human-readable sexp of a full snapshot, so that accidental
   changes to the shape (renamed fields, reordered rows) show up as a
   readable diff here. Every value is built by hand — nothing depends on the
   clock or the GC. *)
let%expect_test "snapshot sexp shape is pinned" =
  let alice = Participant.of_string "Alice" in
  let bob = Participant.of_string "Bob" in
  let aapl = Symbol_id.of_int 0 in
  let bbo : Bbo.t =
    { bid = Some { price = Price.of_int_cents 9_950; size = Size.of_int 10 }
    ; ask = Some { price = Price.of_int_cents 10_050; size = Size.of_int 5 }
    }
  in
  let snapshot : Exchange_stats.t =
    { seq = 1
    ; sampled_at = Time_ns.add Time_ns.epoch Time_ns.Span.minute
    ; gc =
        { live_words = 120_000
        ; heap_words = 250_000
        ; minor_collections = 42
        ; major_collections = 3
        ; promoted_words = 6_000
        ; compactions = 0
        }
    ; latencies =
        { submit =
            histogram_of
              [ Time_ns.Span.of_int_ns 10_000
              ; Time_ns.Span.of_int_ns 20_000
              ]
        ; cancel = histogram_of [ Time_ns.Span.of_int_ns 5_000 ]
        }
    ; pipes =
        { request_queue = 2
        ; audit_subscribers = [ 0; 3 ]
        ; market_data_subscribers = [ aapl, [ 1 ] ]
        ; sessions = [ alice, 0; bob, 4 ]
        ; stats_subscribers = [ 0 ]
        }
    ; participants =
        [ ( alice
          , { orders_submitted = 2
            ; cancels_submitted = 0
            ; resting_orders = 1
            } )
        ; ( bob
          , { orders_submitted = 1
            ; cancels_submitted = 1
            ; resting_orders = 2
            } )
        ]
    ; books =
        [ ( aapl
          , { bbo
            ; bids = { total_size = Size.of_int 10; order_count = 1 }
            ; asks = { total_size = Size.of_int 5; order_count = 2 }
            } )
        ]
    ; fundamentals = [ aapl, Price.of_int_cents 10_000 ]
    ; loop =
        { iterations = 3
        ; gap =
            histogram_of
              [ Time_ns.Span.of_int_ms 1; Time_ns.Span.of_int_ms 2 ]
        }
    }
  in
  print_s [%sexp (snapshot : Exchange_stats.t)];
  [%expect
    {|
    ((seq 1) (sampled_at (1970-01-01 00:01:00.000000000Z))
     (gc
      ((live_words 120000) (heap_words 250000) (minor_collections 42)
       (major_collections 3) (promoted_words 6000) (compactions 0)))
     (latencies
      ((submit (((8us 16us) 1) ((16us 32us) 1))) (cancel (((4us 8us) 1)))))
     (pipes
      ((request_queue 2) (audit_subscribers (0 3))
       (market_data_subscribers ((0 (1)))) (sessions ((Alice 0) (Bob 4)))
       (stats_subscribers (0))))
     (participants
      ((Alice ((orders_submitted 2) (cancels_submitted 0) (resting_orders 1)))
       (Bob ((orders_submitted 1) (cancels_submitted 1) (resting_orders 2)))))
     (books
      ((0
        ((bbo
          ((bid (((price 9950) (size 10)))) (ask (((price 10050) (size 5))))))
         (bids ((total_size 10) (order_count 1)))
         (asks ((total_size 5) (order_count 2)))))))
     (fundamentals ((0 10000)))
     (loop ((iterations 3) (gap (((512us 1.024ms) 1) ((1.024ms 2.048ms) 1))))))
    |}]
;;

(* [of_stat] reads a live [Gc.stat ()], so we print booleans rather than the
   raw (run-dependent) numbers. *)
let%expect_test "Gc_stats.of_stat extracts plausible values" =
  let stats : Exchange_stats.Gc_stats.t =
    Exchange_stats.Gc_stats.of_stat (Gc.stat ())
  in
  print_s
    [%message
      (stats.live_words > 0 : bool)
        (stats.minor_collections >= 0 : bool)
        (stats.promoted_words >= 0 : bool)];
  [%expect
    {|
    (("stats.live_words > 0" true) ("stats.minor_collections >= 0" true)
     ("stats.promoted_words >= 0" true))
    |}]
;;
