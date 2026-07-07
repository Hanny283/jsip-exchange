(** A fixed-layout, log-bucketed histogram of [Time_ns.Span.t] durations for
    the exchange's metrics pipeline.

    Metrics producers record durations (e.g. order-processing latencies) into
    one histogram per reporting interval. Because every histogram shares the
    same fixed bucket layout, histograms from different intervals — or from
    different processes — can be combined with {!merge} to aggregate across
    time windows without retaining raw observations.

    The bucket layout is a wire contract shared with browser clients, which
    render histograms bucket by bucket; do not change it without updating
    them. There are 26 buckets, log-spaced with boundaries [b_i = 1us * 2^i]
    for [i = 0 .. 24] (1us up to 16.777216s):

    - bucket 0 covers 0ns inclusive up to 1us exclusive (negative spans clamp
      here too);
    - bucket [i], for [i] in 1 .. 24, covers [b_(i-1)] inclusive up to [b_i]
      exclusive;
    - bucket 25 is the overflow bucket, covering 16.777216s and above. *)

open! Core

(** A mutable histogram. The sexp rendering shows only non-empty buckets, as
    [((<lower> <upper>) count)] pairs — e.g.
    [(((1us 2us) 3) ((16.777216s INF) 1))] — so expect tests stay readable.
    [bin_io] and [equal] operate on the raw per-bucket counts. *)
type t [@@deriving sexp_of, bin_io, equal]

(** [create ()] is an empty histogram: every bucket's count is zero.

    {[
      let t = Span_histogram.create () in
      Span_histogram.record t (Time_ns.Span.of_int_ns 1_500);
      Span_histogram.total_count t (* = 1 *)
    ]} *)
val create : unit -> t

(** The number of buckets, including the overflow bucket: 26. *)
val num_buckets : int

(** The upper bounds (exclusive) of buckets 0 through 24:
    [bucket_boundaries.(i) = 1us * 2^i]. The overflow bucket (25) has no
    upper bound and so no entry here. Treat this array as read-only. *)
val bucket_boundaries : Time_ns.Span.t array

(** [record t span] increments the count of the bucket containing [span], in
    place and without allocating. Negative spans count in bucket 0. *)
val record : t -> Time_ns.Span.t -> unit

(** [counts t] is a fresh copy of the per-bucket counts (length
    {!num_buckets}), suitable for handing to rendering code. Mutating the
    returned array does not affect [t]. *)
val counts : t -> int array

(** The total number of observations recorded, across all buckets. *)
val total_count : t -> int

(** [is_empty t] is [true] iff no observations have been recorded. *)
val is_empty : t -> bool

(** [merge a b] is a new histogram whose counts are the element-wise sums of
    [a]'s and [b]'s; neither input is modified. Merging is how per-interval
    histograms are aggregated into longer windows. *)
val merge : t -> t -> t

(** [percentile t ~percentile] is the estimated value at [percentile],
    which must lie in (0, 100]: the upper boundary of the bucket in which
    the cumulative count first reaches
    [ceil (percentile /. 100. *. total)]. Observations that landed in the
    overflow bucket report the last boundary (16.777216s), which is a
    lower bound on the truth. Returns [None] if the histogram is empty.
    Raises (via [raise_s]) if [percentile] is outside (0, 100]. *)
val percentile : t -> percentile:float -> Time_ns.Span.t option
