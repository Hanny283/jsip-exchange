(** A two-series inline-SVG line chart for the price pane.

    Draws a solid [market] line and a dashed [fundamental] line on a single
    shared y-axis (min-to-max over both series), so the vertical gap between
    them reads directly as how far the book has drifted from fair value. This
    is a dual-series generalization of {!Sparkline}: same index-based x, same
    fill-the-box y-scaling, but two lines sharing one scale rather than one
    auto-scaled line.

    The two lists are the per-sample series, oldest first and the same length
    (one entry per sample in the window). A [None] entry contributes no
    vertex, so a line bridges a short gap rather than dropping out; a series
    that is entirely [None] simply isn't drawn. When neither series has two
    or more plotted points — so no line can be drawn — a chip-colored
    placeholder box of the same size renders instead. *)

open! Core
open Bonsai_web

(** [view ~width ~height ~market ~fundamental] draws the two series in a
    [width] x [height] px box: [market] as a solid accent line, [fundamental]
    as a dashed muted line, both on a shared y-scale spanning the combined
    min and max. *)
val view
  :  width:int
  -> height:int
  -> market:float option list
  -> fundamental:float option list
  -> Vdom.Node.t
