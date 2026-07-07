(** The "matching loop" pane: is the engine's main loop running smoothly, and
    how fast?

    Renders a {!Dashboard_state.Loop_view}: gap percentiles (elapsed time
    between loop iterations, merged over the whole window), the iteration
    rate, and a sparkline of the worst gap seen in each sample. A loop
    stalled behind a slow downstream shows up here as a gap spike before it
    shows up anywhere else, so the sparkline is deliberately shape-first: any
    lonely peak is worth investigating.

    Tiles show em-dashes and the sparkline a placeholder box until enough
    samples arrive. *)

open! Core
open Bonsai_web

(** [view loop] renders the matching-loop pane for one view record. *)
val view : Dashboard_state.Loop_view.t -> Vdom.Node.t
