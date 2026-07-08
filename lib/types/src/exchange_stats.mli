(** A per-second snapshot of the exchange's internal health, streamed to
    operators by the exchange-stats RPC.

    Each snapshot bundles everything an operator dashboard needs to spot
    trouble: GC pressure, order-processing latencies (as
    {!Span_histogram.t}s), the occupancy of every server-owned pipe,
    per-participant activity, per-symbol book depth, and matching-loop
    cadence. The gateway assembles one [t] per sampling interval and
    broadcasts it to subscribers; the monitor renders it.

    This module is pure data — core-only, no Async — so it can be linked into
    browser clients via js_of_ocaml. All types derive [bin_io] for the RPC
    wire format and [sexp_of] for tests and human inspection. *)

open! Core

(** A digest of [Gc.stat ()] at sampling time — the fields an operator
    watches for memory pressure. All values are cumulative since the server
    process started, so consumers should difference successive snapshots to
    get per-interval rates. *)
module Gc_stats : sig
  type t =
    { live_words : int
    (** Words of live data in the major heap, including headers. *)
    ; heap_words : int (** Total size of the major heap, in words. *)
    ; minor_collections : int (** Minor collections since program start. *)
    ; major_collections : int
    (** Major collection cycles completed since program start. *)
    ; promoted_words : int
    (** Minor-heap words that survived a minor collection and moved to the
        major heap. The runtime reports this as a [float]; we truncate to
        [int], which is exact — GC word counts are far below 2^53. *)
    ; compactions : int (** Heap compactions since program start. *)
    }
  [@@deriving sexp_of, bin_io]

  (** [of_stat stat] extracts the fields above from a full [Gc.Stat.t], as
      returned by [Gc.stat ()]. *)
  val of_stat : Gc.Stat.t -> t
end

(** End-to-end command-processing latencies, from RPC-handler entry to
    matching-engine completion, accumulated over the snapshot interval.
    Histograms reset at each snapshot; aggregate across snapshots with
    {!Span_histogram.merge}. *)
module Latencies : sig
  type t =
    { submit : Span_histogram.t
    (** Latencies of order submissions processed this interval. *)
    ; cancel : Span_histogram.t
    (** Latencies of cancel requests processed this interval. *)
    }
  [@@deriving sexp_of, bin_io]
end

(** The occupancy ([Pipe.length]) of every server-owned pipe at sampling
    time. Rising occupancy on a subscriber pipe means that subscriber is
    reading slower than the server writes — the leading indicator of the
    unbounded-buffering problem with slow consumers. Each subscriber pipe
    contributes one entry to its list. *)
module Pipe_occupancy : sig
  type t =
    { request_queue : int
    (** Commands enqueued by RPC handlers but not yet consumed by the
        matching loop. *)
    ; audit_subscribers : int list
    (** One length per audit-log subscriber pipe. *)
    ; market_data_subscribers : (Symbol.t * int list) list
    (** Per symbol, one length per market-data subscriber pipe. A subscriber
        to several symbols appears under each of them. Sorted by symbol. *)
    ; sessions : (Participant.t * int) list
    (** Length of each logged-in participant's session-feed pipe. Sorted by
        participant. *)
    ; stats_subscribers : int list
    (** One length per subscriber to the exchange-stats RPC itself. *)
    }
  [@@deriving sexp_of, bin_io]
end

(** One participant's activity, reported per snapshot in {!t.participants}. *)
module Participant_stats : sig
  type t =
    { orders_submitted : int
    (** Order submissions accepted by the RPC layer and enqueued during the
        interval — including ones the engine later rejects. *)
    ; cancels_submitted : int
    (** Cancel requests accepted by the RPC layer and enqueued during the
        interval, counted the same way as [orders_submitted]. *)
    ; resting_orders : int
    (** Orders resting on the book at sampling time — a point-in-time
        whole-book scan, not an interval count. *)
    }
  [@@deriving sexp_of, bin_io]
end

(** Aggregate resting interest on one side of a book, summed across all price
    levels. *)
module Side_depth : sig
  type t =
    { total_size : Size.t
    (** Sum of remaining sizes of all resting orders on the side. *)
    ; order_count : int (** Number of resting orders on the side. *)
    }
  [@@deriving sexp_of, bin_io]
end

(** A point-in-time summary of one symbol's book: the best prices plus
    whole-side depth, reported per symbol in {!t.books}. *)
module Book_depth : sig
  type t =
    { bbo : Bbo.t (** Best bid and offer at sampling time. *)
    ; bids : Side_depth.t (** Depth across all bid levels. *)
    ; asks : Side_depth.t (** Depth across all ask levels. *)
    }
  [@@deriving sexp_of, bin_io]
end

(** Matching-loop cadence over the snapshot interval. A loop that stalls
    (e.g. blocked on a slow downstream) shows up as large gaps here before it
    shows up anywhere else. *)
module Loop_stats : sig
  type t =
    { iterations : int
    (** Matching-loop iterations started during the interval. *)
    ; gap : Span_histogram.t
    (** Elapsed time between successive iteration starts. Each gap is
        attributed to the interval in which it completes, so a gap that spans
        a snapshot boundary counts in the later snapshot. *)
    }
  [@@deriving sexp_of, bin_io]
end

(** One snapshot. [seq] increases by 1 per snapshot within a server run, so
    subscribers can detect missed snapshots. The [participants] and [books]
    rows are sorted by key.

    [sampled_at] is a [Time_ns.Stable.V1.t] rather than a plain [Time_ns.t]
    because the latter has no [bin_io] in this version of Core; the two types
    are interchangeable in memory. *)
type t =
  { seq : int (** 1, 2, 3, ... within a server run. *)
  ; sampled_at : Time_ns.Stable.V1.t (** When the snapshot was assembled. *)
  ; gc : Gc_stats.t
  ; latencies : Latencies.t
  ; pipes : Pipe_occupancy.t
  ; participants : (Participant.t * Participant_stats.t) list
  (** One row per participant seen this interval or resting on a book; sorted
      by participant. *)
  ; books : (Symbol.t * Book_depth.t) list
  (** One row per symbol the exchange trades; sorted by symbol. *)
  ; fundamentals : (Symbol.t * Price.t) list
  (** The simulation's fundamental ("fair") price per symbol at sampling
      time, as read from the scenario's price oracle. A dashboard can plot
      this against the observed market price to show how far the book has
      drifted from fair value. One row per symbol whose fundamental is known;
      sorted by symbol, and empty when the exchange runs with no oracle (e.g.
      the standalone server). *)
  ; loop : Loop_stats.t
  }
[@@deriving sexp_of, bin_io]
