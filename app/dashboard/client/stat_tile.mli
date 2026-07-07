(** A small labeled statistic — the dashboard's basic "big number" unit.

    Tiles sit in a {!Styles.tile_row} inside a {!Pane}; each has a fixed
    minimum width and tabular numerals so values can tick every second
    without the row reflowing. The value is a pre-formatted string; callers
    render missing data as a dash ("-") rather than hiding the tile, so a
    pane's shape is stable before its first sample.

    Callable self-closing from ppx_html:

    {[
      {%html|<Stat_tile.view ~label:%{"p99"} ~value:%{"1.2ms"} />|}
    ]} *)

open! Core
open Bonsai_web

(** [view ~label ~value ()] is one tile: [label] set small and muted above
    [value] set in the monospaced numeric style. *)
val view : label:string -> value:string -> unit -> Vdom.Node.t
