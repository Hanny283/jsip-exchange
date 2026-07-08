open! Core

let num_buckets = 26
let overflow_bucket = num_buckets - 1

(* The smallest bucket boundary, 1us, in nanoseconds. Every other boundary is
   a power-of-two multiple of it. *)
let base_boundary_ns = 1000

(* Boundaries are computed with [scale_int] (Int63 arithmetic under the hood)
   rather than [lsl] on a plain [int]: js_of_ocaml's native ints are 32-bit,
   so [1000 lsl i] wraps for i >= 22 in the browser, where clients
   deserialize this type to label buckets. [1 lsl i] itself stays well within
   32 bits (i <= 24). *)
let bucket_boundaries =
  Array.init (num_buckets - 1) ~f:(fun i ->
    Time_ns.Span.scale_int (Time_ns.Span.of_int_ns base_boundary_ns) (1 lsl i))
;;

type t = { counts : int array } [@@deriving bin_io, equal]

let sexp_of_t t =
  let bucket_range index =
    let lower =
      match index with
      | 0 -> Time_ns.Span.to_string Time_ns.Span.zero
      | index -> Time_ns.Span.to_string bucket_boundaries.(index - 1)
    in
    let upper =
      match index = overflow_bucket with
      | true -> "INF"
      | false -> Time_ns.Span.to_string bucket_boundaries.(index)
    in
    Sexp.List [ Sexp.Atom lower; Sexp.Atom upper ]
  in
  let non_empty_buckets =
    Array.to_list t.counts
    |> List.filter_mapi ~f:(fun index count ->
      match count with
      | 0 -> None
      | count -> Some (Sexp.List [ bucket_range index; sexp_of_int count ]))
  in
  Sexp.List non_empty_buckets
;;

let create () = { counts = Array.create ~len:num_buckets 0 }

(* Int63 throughout: [Time_ns.Span.to_int_ns] raises on 32-bit platforms
   (js_of_ocaml), and span magnitudes can exceed a 32-bit [int] anyway. *)
let bucket_index span =
  let ns = Time_ns.Span.to_int63_ns span in
  let base = Int63.of_int base_boundary_ns in
  match Int63.( < ) ns base with
  | true -> 0
  | false ->
    Int.min
      overflow_bucket
      (Int63.to_int_exn (Int63.floor_log2 (Int63.( / ) ns base)) + 1)
;;

let record t span =
  let index = bucket_index span in
  t.counts.(index) <- t.counts.(index) + 1
;;

let counts t = Array.copy t.counts
let total_count t = Array.sum (module Int) t.counts ~f:Fn.id
let is_empty t = total_count t = 0
let merge a b = { counts = Array.map2_exn a.counts b.counts ~f:( + ) }

let percentile t ~percentile =
  if Float.O.(percentile <= 0. || percentile > 100.)
  then raise_s [%message "percentile out of range" (percentile : float)];
  match total_count t with
  | 0 -> None
  | total ->
    let target_rank =
      Float.round_up (percentile /. 100. *. Float.of_int total)
      |> Float.to_int
    in
    (* Walk the buckets accumulating counts; the first bucket whose
       cumulative count reaches the target rank holds the estimate. The
       overflow bucket has no boundary of its own, so it reports the last
       finite boundary (a lower bound on the true value). *)
    let rec find index cumulative =
      let cumulative = cumulative + t.counts.(index) in
      if cumulative >= target_rank
      then Int.min index (overflow_bucket - 1)
      else find (index + 1) cumulative
    in
    Some bucket_boundaries.(find 0 0)
;;
