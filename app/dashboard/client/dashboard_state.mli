(** The dashboard client's pure model: a sliding window of
    {!Jsip_types.Exchange_stats.t} snapshots, plus the per-pane view
    computations over that window.

    The browser client polls the dashboard server's
    {!Jsip_dashboard_protocol.Recent_samples} RPC about once a second and
    folds each response into a [t] with {!handle_response}. The Bonsai layer
    then derives one [*_view] record per pane and renders those; it never
    reads [Exchange_stats] fields directly. Keeping that boundary here — the
    only client module that touches [Exchange_stats] field names — means a
    wire-type change lands in exactly one place.

    This module is deliberately pure: no Bonsai, no Vdom, no clock. Time only
    enters through the samples' own [sampled_at] stamps (eviction and slicing
    are relative to the newest sample, never the wall clock), so everything
    here is testable with ordinary native expect tests.

    A typical polling step looks like:

    {[
      let query =
        { Recent_samples.Query.after_seq = Dashboard_state.latest_seq state }
      in
      (* ... dispatch the RPC, receive [response] ... *)
      let state = Dashboard_state.handle_response state response in
      let memory = Dashboard_state.memory_view state in
      (* render [memory.points] as a sparkline, etc. *)
    ]} *)

open! Core
open Jsip_types

(** A bounded window of snapshots, newest-last, plus the window length it was
    created with. The sexp rendering shows the raw window contents; it is for
    debugging and tests, not for the wire. *)
type t [@@deriving sexp_of]

(** [create ~window] is an empty state that will retain samples no older than
    [window] relative to the newest sample it holds (see {!handle_response}).
    The dashboard uses a couple of minutes. A non-positive [window] is not an
    error; it just means only the newest sample survives eviction. *)
val create : window:Time_ns.Span.t -> t

(** [handle_response t response] folds one polling response into the window:

    - If [response.latest_seq] — or any sample's [seq] — is {e below} our
      cursor ({!latest_seq}), the server (or the exchange behind it)
      restarted and snapshot numbering began again: the window is reset
      before anything is appended.
    - Samples are appended in ascending [seq] order; stale or duplicate
      samples ([seq <=] the cursor as it advances) are ignored, so
      overlapping responses are harmless.
    - Finally, samples whose [sampled_at] is more than the window older than
      the {e newest} sample's [sampled_at] are evicted. Using the newest
      sample rather than the wall clock keeps this function deterministic. *)
val handle_response
  :  t
  -> Jsip_dashboard_protocol.Recent_samples.Response.t
  -> t

(** The [seq] of the newest sample held, or [None] if the window is empty.
    This is the cursor to send as the next query's [after_seq]. *)
val latest_seq : t -> int option

(** The number of samples currently in the window. *)
val sample_count : t -> int

(** All symbols with a book row in any sample of the window, sorted. The
    union (rather than just the newest sample) keeps a symbol selectable even
    if it briefly drops out of a snapshot. *)
val symbols : t -> Symbol.t list

(** The direction of a pipe-occupancy reading over the last ~10 seconds. A
    queue counts as [Rising] only when it grew by more than
    [max 5 (older / 5)] — an absolute floor so tiny queues don't flap, and a
    20% band so big queues need a proportional move; [Falling] is the mirror
    image, and everything in between is [Flat]. *)
module Trend : sig
  type t =
    | Rising
    | Flat
    | Falling
  [@@deriving sexp_of, equal]
end

(** What the memory pane renders: a sparkline of live-heap sizes and its
    endpoint growth rate. All views derive [equal] so the Bonsai layer can
    cut off recomputation when a view is unchanged. *)
module Memory_view : sig
  type t =
    { points : float list
    (** [gc.live_words] per sample, oldest first, over the last 60 seconds of
        the window. *)
    ; live_words : int option
    (** The newest sample's [gc.live_words]; [None] when the window is empty. *)
    ; growth_words_per_sec : float option
    (** Endpoint slope of [points]: (last - first) / seconds between those
        two samples. [None] with fewer than two points or when the endpoints
        share a timestamp. *)
    }
  [@@deriving sexp_of, equal]
end

(** [memory_view t] summarizes GC pressure over the last 60 seconds of the
    window (a fixed slice, independent of the window length). *)
val memory_view : t -> Memory_view.t

(** What a latency pane renders: percentiles and a bucketed histogram of one
    command's processing latency, aggregated over the whole window. *)
module Latency_view : sig
  type t =
    { p50 : Time_ns.Span.t option
    (** Median latency; [None] when no observations. *)
    ; p90 : Time_ns.Span.t option (** 90th percentile. *)
    ; p99 : Time_ns.Span.t option (** 99th percentile. *)
    ; buckets : (string * int) list
    (** Non-empty histogram buckets only, in span order, labeled
        ["<lower>-<upper>"] (e.g. ["8us-16us"]); the first bucket is ["<1us"]
        and the overflow bucket [">=16.8s"]. *)
    ; total : int (** Total observations across all buckets. *)
    }
  [@@deriving sexp_of, equal]
end

(** [submit_latency_view t] merges every sample's [latencies.submit]
    histogram ({!Span_histogram.merge}) and reports percentiles and buckets
    of the merged whole. *)
val submit_latency_view : t -> Latency_view.t

(** [cancel_latency_view t] is {!submit_latency_view} for [latencies.cancel]. *)
val cancel_latency_view : t -> Latency_view.t

(** What the pipe-occupancy pane renders: one row per server-owned pipe in
    the newest sample. *)
module Occupancy_view : sig
  module Row : sig
    type t =
      { name : string
      (** A stable display name: ["request-queue"], ["audit[i]"],
          ["md:<SYMBOL>[i]"], ["session:<participant>"], or ["stats[i]"],
          where [i] indexes subscribers of that kind. *)
      ; length : int (** The pipe's occupancy in the newest sample. *)
      ; trend : Trend.t
      (** Direction versus the sample ~10s older (or the oldest sample in a
          shorter window), matched by [name]; [Flat] if the pipe did not
          exist then. *)
      }
    [@@deriving sexp_of, equal]
  end

  type t = Row.t list [@@deriving sexp_of, equal]
end

(** [occupancy_view t] lists every pipe of the newest sample with its
    occupancy and trend; empty when the window is empty. *)
val occupancy_view : t -> Occupancy_view.t

(** What the participants pane renders: per-participant activity rates and
    resting interest. *)
module Participants_view : sig
  module Row : sig
    type t =
      { participant : Participant.t
      ; orders_per_sec : float
      (** Mean of per-interval [orders_submitted] over up to the last 10
          samples (snapshots arrive about once a second, so a mean per
          interval reads as a per-second rate). A participant missing from an
          interval counts as 0 for it. *)
      ; cancels_per_sec : float
      (** Mean of per-interval [cancels_submitted], computed like
          [orders_per_sec]. *)
      ; resting_orders : int
      (** Resting orders in the newest sample; 0 if the participant is absent
          from it. *)
      }
    [@@deriving sexp_of, equal]
  end

  type t = Row.t list [@@deriving sexp_of, equal]
end

(** [participants_view t] has one row per participant appearing in any of the
    last 10 samples, sorted by participant; empty when the window is empty. *)
val participants_view : t -> Participants_view.t

(** What the book-depth pane renders for one symbol, from the newest sample
    only. *)
module Depth_view : sig
  type t =
    { bbo : Bbo.t option
    (** The best bid and offer; [None] when both sides of the book are empty,
        so the pane can render a dash instead of two blanks. *)
    ; bid_size : Size.t (** Total resting size across all bid levels. *)
    ; bid_orders : int (** Resting order count across all bid levels. *)
    ; ask_size : Size.t (** Total resting size across all ask levels. *)
    ; ask_orders : int (** Resting order count across all ask levels. *)
    }
  [@@deriving sexp_of, equal]
end

(** [depth_view t ~symbol] summarizes [symbol]'s book in the newest sample,
    or [None] when the window is empty or the newest sample has no row for
    [symbol]. *)
val depth_view : t -> symbol:Symbol.t -> Depth_view.t option

(** What the matching-loop pane renders: gap percentiles over the whole
    window, a worst-gap-per-sample sparkline, and the iteration rate. *)
module Loop_view : sig
  type t =
    { p50 : Time_ns.Span.t option
    (** Median loop gap over the window-merged [loop.gap] histograms; [None]
        when no gaps were recorded. *)
    ; p99 : Time_ns.Span.t option (** 99th percentile loop gap. *)
    ; max_gap_points : float list
    (** Per sample, oldest first: the upper boundary (in seconds) of the
        highest non-empty bucket of that sample's [loop.gap] — an upper bound
        on the worst gap seen that interval. 0 when the sample recorded no
        gaps; observations in the overflow bucket report the last boundary
        (16.777216s), a lower bound. *)
    ; iterations_per_sec : float option
    (** Mean of per-interval [loop.iterations] over up to the last 10
        samples; [None] when the window is empty. *)
    }
  [@@deriving sexp_of, equal]
end

(** [loop_view t] summarizes matching-loop cadence: how evenly the loop is
    running (percentiles, worst gaps) and how fast (iteration rate). *)
val loop_view : t -> Loop_view.t
