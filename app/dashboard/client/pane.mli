(** The dashboard's panel primitive: a titled card in the pane grid.

    Every pane on the dashboard is one [Pane.view] so that titles, padding,
    and elevation stay identical across panes. Children stack vertically with
    a consistent gap (see {!Styles.panel}).

    Callable from ppx_html with children syntax:

    {[
      {%html|
        <Pane.view ~title:%{"gc / memory"}>
          %{tiles}
          %{sparkline}
        </>
      |}
    ]} *)

open! Core
open Bonsai_web

(** [view ~title children] is a panel card headed by [title] (rendered as a
    small uppercase label) with [children] stacked beneath it. *)
val view : title:string -> Vdom.Node.t list -> Vdom.Node.t
