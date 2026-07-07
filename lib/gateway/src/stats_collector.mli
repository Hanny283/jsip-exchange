(** Mutable accumulator for the exchange's observe-as-they-happen metrics:
    command-processing latencies, matching-loop cadence, and per-participant
    command counts.

    The matching loop and the RPC handlers record into one
    [Stats_collector.t] as events occur; once per sampling interval the stats
    publisher calls {!flush} to take ownership of everything accumulated so
    far and reset the collector for the next interval. The flushed values
    slot directly into the interval-scoped fields of an
    {!Jsip_types.Exchange_stats.t} snapshot.

    The API takes explicit times — [flush] and [record_loop_iteration] never
    read a clock — so tests can drive it deterministically:

    {[
      let collector = Stats_collector.create () in
      Stats_collector.record_loop_iteration collector ~now:Time_ns.epoch;
      Stats_collector.record_submit_latency
        collector
        (Time_ns.Span.of_int_us 10);
      let flushed = Stats_collector.flush collector in
      print_s [%sexp (flushed : Stats_collector.Flushed.t)]
    ]} *)

open! Core
open Jsip_types

type t

(** [create ()] is an empty collector: no latencies recorded, no loop
    iterations seen, no per-participant counts. *)
val create : unit -> t

(** [record_submit_latency t span] records one order submission's end-to-end
    latency (RPC-handler entry to matching-engine completion) into the
    current interval's submit histogram. *)
val record_submit_latency : t -> Time_ns.Span.t -> unit

(** As {!record_submit_latency}, for cancel requests. *)
val record_cancel_latency : t -> Time_ns.Span.t -> unit

(** [record_loop_iteration t ~now] bumps the interval's iteration count and,
    from the second call on, records the gap between [now] and the previous
    call's [now] into the loop-gap histogram. The previous iteration time
    survives {!flush}, so a gap that spans a sampling boundary is attributed
    to the interval in which it ends. *)
val record_loop_iteration : t -> now:Time_ns.t -> unit

(** [incr_orders_submitted t participant] counts one order submission
    accepted by the RPC layer and enqueued for [participant] during the
    interval — including submissions the engine later rejects. *)
val incr_orders_submitted : t -> Participant.t -> unit

(** As {!incr_orders_submitted}, for cancel requests. *)
val incr_cancels_submitted : t -> Participant.t -> unit

(** Everything one {!flush} hands back: the interval's accumulated metrics,
    shaped for direct inclusion in an {!Jsip_types.Exchange_stats.t}. *)
module Flushed : sig
  (** Per-participant command counts for the interval — the interval half of
      {!Exchange_stats.Participant_stats.t}. The publisher joins in
      [resting_orders] from a point-in-time book scan. *)
  module Counts : sig
    type t =
      { orders_submitted : int
      (** Order submissions enqueued this interval. *)
      ; cancels_submitted : int
      (** Cancel requests enqueued this interval. *)
      }
    [@@deriving sexp_of]
  end

  type t =
    { latencies : Exchange_stats.Latencies.t
    ; per_participant : (Participant.t * Counts.t) list
    (** One row per participant that submitted at least one command this
        interval; sorted by participant. *)
    ; loop : Exchange_stats.Loop_stats.t
    }
  [@@deriving sexp_of]
end

(** [flush t] returns everything accumulated since the previous flush (or
    since {!create}) and resets [t] for the next interval: fresh histograms
    are installed and all counters return to zero. Ownership of the returned
    histograms transfers to the caller — [t] never mutates them afterwards;
    callers must likewise not mutate what they receive if they hand it on
    (e.g. into a snapshot). The only state that survives is the time of the
    most recent loop iteration, so the next {!record_loop_iteration} still
    measures a gap across the flush boundary. *)
val flush : t -> Flushed.t
