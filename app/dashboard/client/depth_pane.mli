(** The "book depth" pane: one symbol's best prices and whole-side depth,
    with a selector for which symbol to watch.

    Unlike the other panes this is a component, not a pure view: it owns the
    selected symbol as Bonsai state. The effective symbol is the selection
    while it exists in {!Dashboard_state.symbols}, otherwise the first symbol
    — so the pane self-heals when a symbol drops out of the window and
    remembers the choice if it comes back.

    The body shows the newest sample's {!Dashboard_state.Depth_view}: best
    bid (mint) and ask (red) with the spread between them, and total size /
    order count per side as tiles. Renders an em-dash empty state until the
    window contains any book at all. *)

open! Core
open Bonsai_web

(** [component ~state graph] is the pane's vdom, re-rendered as [state] (the
    polling window) and the symbol selection change. *)
val component
  :  state:Dashboard_state.t Bonsai.t
  -> local_ Bonsai.graph
  -> Vdom.Node.t Bonsai.t
