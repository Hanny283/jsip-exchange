(** The "price over time" pane: one symbol's observed market price plotted
    against its fundamental (fair) value across the window, with a selector
    for which symbol to watch.

    Like {!Depth_pane} — and unlike the pure-view panes — this is a component
    that owns the selected symbol as Bonsai state, falling back to the first
    available symbol whenever the selection isn't in
    {!Dashboard_state.symbols}, so it self-heals when a symbol drops out of
    the window and remembers the choice if it returns.

    The body shows the latest market mid and fundamental as tiles above a
    {!Price_chart}: a solid accent line for the market mid (what the book
    trades around) and a dashed muted line for the fundamental (where the
    oracle says fair value is), so their divergence is visible at a glance.
    Renders an em-dash empty state until the window holds any book. *)

open! Core
open Bonsai_web

(** [component ~state graph] is the pane's vdom, re-rendered as [state] (the
    polling window) and the symbol selection change. *)
val component
  :  state:Dashboard_state.t Bonsai.t
  -> local_ Bonsai.graph
  -> Vdom.Node.t Bonsai.t
