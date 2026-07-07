(** Fixed-height bar rendering for bucketed latency histograms.

    Renders the non-empty buckets of a {!Dashboard_state.Latency_view}
    (labels like ["8us-16us"] with counts) as a row of accent-colored bars,
    heights proportional to the largest bucket. Because buckets can be
    numerous and their labels wide, only the lowest and highest bucket labels
    print under the row; every bar carries its exact ["label: count"] as a
    hover tooltip.

    The row has a fixed height whether it holds bars or the "no observations"
    placeholder, so latency panes never jump as data arrives or drains out of
    the window. *)

open! Core
open Bonsai_web

(** [view ~buckets] renders [buckets] (in increasing span order, as produced
    by {!Dashboard_state.submit_latency_view}) as proportional bars, or a
    same-height "no observations" box when empty. *)
val view : buckets:(string * int) list -> Vdom.Node.t
