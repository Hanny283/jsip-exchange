(** The "pipe occupancy" pane: one row per server-owned pipe, with its depth
    and a ~10-second trend.

    This is the pane that catches the slow-consumer problem: a subscriber
    that reads slower than the exchange writes shows up here as a depth that
    only rises. Rising trends render as an amber ▲ (trouble brewing), falling
    as a mint ▼ (draining), flat as a muted dash — so a scan down the column
    finds the misbehaving pipe.

    Rows come straight from a {!Dashboard_state.Occupancy_view} (the newest
    sample). The table scrolls inside the pane past ~230px, so dozens of
    market-data subscriptions cannot stretch the grid. Shows a "no pipes
    reported yet" note until the first sample arrives. *)

open! Core
open Bonsai_web

(** [view rows] renders the occupancy table, or its empty state. *)
val view : Dashboard_state.Occupancy_view.t -> Vdom.Node.t
