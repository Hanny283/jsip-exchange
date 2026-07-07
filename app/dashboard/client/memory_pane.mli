(** The "gc / memory" pane: is the exchange's heap growing?

    Renders a {!Dashboard_state.Memory_view}: the newest live-heap size (as
    bytes, assuming the server's 8-byte words), the endpoint growth rate
    (signed words/sec — steady growth here is the first hint of a leak, e.g.
    an unbounded subscriber pipe), and a 60-second sparkline of live words
    for shape.

    Before the first samples arrive the tiles show em-dashes and the
    sparkline renders as a placeholder box, so the pane's layout is stable
    from first paint. *)

open! Core
open Bonsai_web

(** [view memory] renders the memory pane for one derived view record. *)
val view : Dashboard_state.Memory_view.t -> Vdom.Node.t
