(** Tests for {!Jsip_gateway.Stats_collector}.

    The collector's API takes explicit times, so every test drives it with
    [Time_ns.epoch] plus small offsets — no clock reads, fully deterministic
    output. *)

open! Core
open Jsip_gateway
open Jsip_test_harness

(* Pretend the matching loop started an iteration [ms] milliseconds after the
   epoch. *)
let iterate_at collector ~ms =
  Stats_collector.record_loop_iteration
    collector
    ~now:(Time_ns.add Time_ns.epoch (Time_ns.Span.of_int_ms ms))
;;

let print_flushed flushed =
  print_s [%sexp (flushed : Stats_collector.Flushed.t)]
;;

let%expect_test "flush hands back the interval's accumulated metrics" =
  let collector = Stats_collector.create () in
  Stats_collector.record_submit_latency collector (Time_ns.Span.of_int_us 10);
  Stats_collector.record_submit_latency collector (Time_ns.Span.of_int_us 20);
  Stats_collector.record_cancel_latency
    collector
    (Time_ns.Span.of_int_us 100);
  (* Bob before Alice, to show the flushed rows come out sorted by
     participant regardless of arrival order. *)
  Stats_collector.incr_orders_submitted collector Harness.bob;
  Stats_collector.incr_orders_submitted collector Harness.alice;
  Stats_collector.incr_orders_submitted collector Harness.alice;
  Stats_collector.incr_cancels_submitted collector Harness.bob;
  (* Iterations at 0ms, 1ms and 3ms: three iterations, two gaps (1ms and
     2ms), which land in adjacent histogram buckets. *)
  iterate_at collector ~ms:0;
  iterate_at collector ~ms:1;
  iterate_at collector ~ms:3;
  print_flushed (Stats_collector.flush collector);
  [%expect
    {|
    ((latencies
      ((submit (((8us 16us) 1) ((16us 32us) 1))) (cancel (((64us 128us) 1)))))
     (per_participant
      ((Alice ((orders_submitted 2) (cancels_submitted 0)))
       (Bob ((orders_submitted 1) (cancels_submitted 1)))))
     (loop ((iterations 3) (gap (((512us 1.024ms) 1) ((1.024ms 2.048ms) 1))))))
    |}]
;;

let%expect_test "flush resets the interval but the loop clock survives" =
  let collector = Stats_collector.create () in
  iterate_at collector ~ms:0;
  iterate_at collector ~ms:3;
  let (_ : Stats_collector.Flushed.t) = Stats_collector.flush collector in
  (* An immediate second flush: nothing has accumulated. *)
  print_flushed (Stats_collector.flush collector);
  [%expect
    {|
    ((latencies ((submit ()) (cancel ()))) (per_participant ())
     (loop ((iterations 0) (gap ()))))
    |}];
  (* The pre-flush iteration time survives flushing: the next iteration
     measures its gap against the 3ms iteration above, so 5ms - 3ms = 2ms is
     attributed to the new interval. *)
  iterate_at collector ~ms:5;
  print_flushed (Stats_collector.flush collector);
  [%expect
    {|
    ((latencies ((submit ()) (cancel ()))) (per_participant ())
     (loop ((iterations 1) (gap (((1.024ms 2.048ms) 1))))))
    |}]
;;

let%expect_test "a flushed snapshot is immune to later recording" =
  let collector = Stats_collector.create () in
  Stats_collector.record_submit_latency collector (Time_ns.Span.of_int_us 10);
  iterate_at collector ~ms:0;
  iterate_at collector ~ms:1;
  Stats_collector.incr_orders_submitted collector Harness.alice;
  let first = Stats_collector.flush collector in
  print_flushed first;
  [%expect
    {|
    ((latencies ((submit (((8us 16us) 1))) (cancel ())))
     (per_participant ((Alice ((orders_submitted 1) (cancels_submitted 0)))))
     (loop ((iterations 2) (gap (((512us 1.024ms) 1))))))
    |}];
  (* Record more of everything, into the same buckets the first snapshot
     already has counts in. If flush failed to transfer histogram ownership,
     [first] would now show doubled counts. *)
  Stats_collector.record_submit_latency collector (Time_ns.Span.of_int_us 10);
  Stats_collector.record_cancel_latency collector (Time_ns.Span.of_int_us 10);
  iterate_at collector ~ms:2;
  Stats_collector.incr_orders_submitted collector Harness.alice;
  print_flushed first;
  [%expect
    {|
    ((latencies ((submit (((8us 16us) 1))) (cancel ())))
     (per_participant ((Alice ((orders_submitted 1) (cancels_submitted 0)))))
     (loop ((iterations 2) (gap (((512us 1.024ms) 1))))))
    |}]
;;
