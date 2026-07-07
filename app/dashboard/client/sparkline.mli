(** A minimal inline-SVG line chart for second-by-second series.

    The dashboard uses sparklines for shapes-over-time where the exact values
    matter less than the trend — live heap words ({!Memory_pane}) and worst
    matching-loop gap per sample ({!Loop_pane}). The series is scaled to fill
    the box: the y-axis runs from the window's minimum to its maximum, so a
    sparkline shows shape, not absolute scale (pair it with a {!Stat_tile}
    for the current value).

    With fewer than two points there is nothing to draw; a chip-colored box
    of exactly the same size renders instead, so panes keep their layout
    while the first samples trickle in. *)

open! Core
open Bonsai_web

(** [view ~width ~height ~values] draws [values] (oldest first) as an
    accent-colored polyline in a [width] x [height] px box. A constant series
    draws as a centered flat line; an empty or single-point series draws as
    an empty placeholder box. *)
val view : width:int -> height:int -> values:float list -> Vdom.Node.t
