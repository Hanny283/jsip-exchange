open! Core
open Jsip_types

let%expect_test "bucket layout is pinned" =
  print_s [%sexp (Span_histogram.num_buckets : int)];
  let boundaries = Span_histogram.bucket_boundaries in
  print_endline (Time_ns.Span.to_string boundaries.(0));
  print_endline (Time_ns.Span.to_string boundaries.(1));
  print_endline
    (Time_ns.Span.to_string boundaries.(Array.length boundaries - 1));
  [%expect {|
    26
    1us
    2us
    16.777216s
    |}]
;;

let%expect_test "recording buckets observations" =
  let t = Span_histogram.create () in
  List.iter
    [ Time_ns.Span.zero
    ; Time_ns.Span.of_int_ns 999
    ; Time_ns.Span.of_int_ns 1_000 (* 1us *)
    ; Time_ns.Span.of_int_ns 1_500 (* 1.5us *)
    ; Time_ns.Span.of_int_ns 2_000 (* 2us *)
    ; Time_ns.Span.of_int_ns 1_000_000 (* 1ms *)
    ; Time_ns.Span.of_int_ns 1_000_000_000 (* 1s *)
    ; Time_ns.Span.hour
    ; Time_ns.Span.of_int_ns (-42)
    ]
    ~f:(Span_histogram.record t);
  print_s [%sexp (t : Span_histogram.t)];
  [%expect
    {|
    (((0s 1us) 3) ((1us 2us) 2) ((2us 4us) 1) ((512us 1.024ms) 1)
     ((524.288ms 1.048576s) 1) ((16.777216s INF) 1))
    |}]
;;

let%expect_test "merge equals recording into one" =
  let record_all spans =
    let t = Span_histogram.create () in
    List.iter spans ~f:(Span_histogram.record t);
    t
  in
  let first_half =
    [ Time_ns.Span.of_int_ns 500
    ; Time_ns.Span.of_int_ns 3_000
    ; Time_ns.Span.of_int_ns 1_000_000
    ]
  in
  let second_half =
    [ Time_ns.Span.of_int_ns 3_500
    ; Time_ns.Span.of_int_ns 2_000_000
    ; Time_ns.Span.hour
    ]
  in
  let a = record_all first_half in
  let b = record_all second_half in
  let combined = record_all (first_half @ second_half) in
  let merged = Span_histogram.merge a b in
  [%test_result: bool] (Span_histogram.equal merged combined) ~expect:true;
  [%test_result: int]
    (Span_histogram.total_count merged)
    ~expect:(Span_histogram.total_count a + Span_histogram.total_count b)
;;

(* Fails until TODO(human) percentile is implemented. *)
let%expect_test "empty histogram" =
  let t = Span_histogram.create () in
  [%test_result: bool] (Span_histogram.is_empty t) ~expect:true;
  [%test_result: int] (Span_histogram.total_count t) ~expect:0;
  print_s
    [%sexp
      (Span_histogram.percentile t ~percentile:50. : Time_ns.Span.t option)];
  [%expect {| () |}]
;;

(* Fails until TODO(human) percentile is implemented. *)
let%expect_test "percentiles on a known distribution" =
  let t = Span_histogram.create () in
  let record_times count span =
    for _ = 1 to count do
      Span_histogram.record t span
    done
  in
  record_times 50 (Time_ns.Span.of_int_ns 10_000) (* 10us *);
  record_times 40 (Time_ns.Span.of_int_ns 1_000_000) (* 1ms *);
  record_times 10 (Time_ns.Span.of_int_ns 100_000_000) (* 100ms *);
  let print_percentile percentile =
    match Span_histogram.percentile t ~percentile with
    | None -> print_endline "none"
    | Some span -> print_endline (Time_ns.Span.to_string span)
  in
  print_percentile 50.;
  print_percentile 90.;
  print_percentile 99.;
  [%expect {|
    16us
    1.024ms
    131.072ms
    |}]
;;
