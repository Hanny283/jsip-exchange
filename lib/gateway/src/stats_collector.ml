open! Core
open Jsip_types

type t =
  { mutable submit_latency : Span_histogram.t
  ; mutable cancel_latency : Span_histogram.t
  ; mutable loop_gap : Span_histogram.t
  ; mutable loop_iterations : int
  ; mutable last_loop_iteration_at : Time_ns.t option
      (* Deliberately survives [flush]: a gap spanning a sampling boundary
         counts in the interval where it ends. *)
  ; orders_submitted : int ref Participant.Table.t
  ; cancels_submitted : int ref Participant.Table.t
  }

let create () =
  { submit_latency = Span_histogram.create ()
  ; cancel_latency = Span_histogram.create ()
  ; loop_gap = Span_histogram.create ()
  ; loop_iterations = 0
  ; last_loop_iteration_at = None
  ; orders_submitted = Participant.Table.create ()
  ; cancels_submitted = Participant.Table.create ()
  }
;;

let record_submit_latency t span =
  Span_histogram.record t.submit_latency span
;;

let record_cancel_latency t span =
  Span_histogram.record t.cancel_latency span
;;

let record_loop_iteration t ~now =
  t.loop_iterations <- t.loop_iterations + 1;
  (match t.last_loop_iteration_at with
   | None -> ()
   | Some previous ->
     Span_histogram.record t.loop_gap (Time_ns.diff now previous));
  t.last_loop_iteration_at <- Some now
;;

let bump table participant =
  incr (Hashtbl.find_or_add table participant ~default:(fun () -> ref 0))
;;

let incr_orders_submitted t participant = bump t.orders_submitted participant

let incr_cancels_submitted t participant =
  bump t.cancels_submitted participant
;;

module Flushed = struct
  module Counts = struct
    type t =
      { orders_submitted : int
      ; cancels_submitted : int
      }
    [@@deriving sexp_of]
  end

  type t =
    { latencies : Exchange_stats.Latencies.t
    ; per_participant : (Participant.t * Counts.t) list
    ; loop : Exchange_stats.Loop_stats.t
    }
  [@@deriving sexp_of]
end

let flush t =
  let count_in table participant =
    match Hashtbl.find table participant with
    | None -> 0
    | Some count -> !count
  in
  let per_participant =
    Hashtbl.keys t.orders_submitted @ Hashtbl.keys t.cancels_submitted
    |> List.dedup_and_sort ~compare:Participant.compare
    |> List.map ~f:(fun participant ->
      let counts : Flushed.Counts.t =
        { orders_submitted = count_in t.orders_submitted participant
        ; cancels_submitted = count_in t.cancels_submitted participant
        }
      in
      participant, counts)
  in
  let flushed : Flushed.t =
    { latencies = { submit = t.submit_latency; cancel = t.cancel_latency }
    ; per_participant
    ; loop = { iterations = t.loop_iterations; gap = t.loop_gap }
    }
  in
  (* Install fresh histograms rather than clearing the flushed ones:
     ownership of the returned histograms transfers to the caller, and this
     collector must never mutate them again. [last_loop_iteration_at]
     survives on purpose — see the mli. *)
  t.submit_latency <- Span_histogram.create ();
  t.cancel_latency <- Span_histogram.create ();
  t.loop_gap <- Span_histogram.create ();
  t.loop_iterations <- 0;
  Hashtbl.clear t.orders_submitted;
  Hashtbl.clear t.cancels_submitted;
  flushed
;;
