(** The "participants" pane: who is trading, how hard, and how much they have
    resting on the books.

    One row per participant from a {!Dashboard_state.Participants_view}:
    order and cancel submission rates (mean per second over the last ~10
    samples, so a burst decays rather than vanishing instantly) and the
    resting-order count from the newest sample. Numeric columns are
    right-aligned tabular numerals, so rates tick in place.

    The table scrolls inside the pane past ~230px — a scenario that logs in
    many bots cannot break the grid — and shows a "no participants in window"
    note when empty. *)

open! Core
open Bonsai_web

(** [view rows] renders the participants table, or its empty state. *)
val view : Dashboard_state.Participants_view.t -> Vdom.Node.t
