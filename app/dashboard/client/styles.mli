(** The dashboard's design tokens: one [Vdom.Attr.t] per reusable style, plus
    the raw hex colors for code that draws its own pixels (SVG).

    This project deliberately has no ppx_css, and ppx_html's [style=]
    attribute desugars to it — so panes never write [style=] inline. Instead
    every style lives here as a plain [Vdom.Attr.create "style" "..."] token
    and is interpolated as a whole attribute:

    {[
      {%html|<div %{Styles.tile}>...</div>|}
    ]}

    The look is a dense, dark developer tool: near-black page, slightly
    lifted panels, chip-colored insets, one blue accent, and monospaced
    tabular numerals everywhere a number ticks. Keeping every color and
    spacing decision in this one module is what keeps the seven panes
    visually consistent. *)

open! Core
open Bonsai_web

(** {2 Palette}

    Hex strings for the few places that need a color as data rather than as a
    style attribute — e.g. {!Sparkline}'s SVG stroke. *)

(** Page background (near-black). *)
val page_bg_hex : string

(** Pane background, one step lighter. *)
val panel_bg_hex : string

(** Inset chips: tiles, quote rows, empty boxes. *)
val chip_bg_hex : string

(** 1px hairlines around panels and inputs. *)
val border_hex : string

(** Primary text (off-white). *)
val text_hex : string

(** Secondary text: labels, captions, em-dashes. *)
val muted_hex : string

(** The one accent (blue): sparklines, histogram. *)
val accent_hex : string

(** Amber: rising queues. *)
val warn_hex : string

(** Red: failures, ask side. *)
val bad_hex : string

(** Mint: healthy/live, falling queues, bid side. *)
val ok_hex : string

(** {2 Page chrome} *)

(** Whole-page wrapper: background, base font, [color-scheme: dark]. *)
val page : Vdom.Attr.t

(** Sticky top strip holding the product name and connection status. *)
val banner : Vdom.Attr.t

(** Left cluster of the banner. *)
val banner_left : Vdom.Attr.t

(** Product name lockup. *)
val banner_product : Vdom.Attr.t

(** Muted subtitle next to the product name. *)
val banner_note : Vdom.Attr.t

(** Right cluster of the banner: the Reset button and the status chip. *)
val banner_right : Vdom.Attr.t

(** The Reset button in the banner. *)
val reset_button : Vdom.Attr.t

(** Pill wrapping the status dot + label. *)
val status_chip : Vdom.Attr.t

(** Status dot: waiting for the first sample. *)
val dot_muted : Vdom.Attr.t

(** Status dot: live. *)
val dot_ok : Vdom.Attr.t

(** Status dot: polling is failing. *)
val dot_bad : Vdom.Attr.t

(** One-line ellipsized error text inside the status chip. *)
val error_detail : Vdom.Attr.t

(** {2 Pane grid and panels} *)

(** Responsive pane grid: [repeat(auto-fit, minmax(340px, 1fr))]. *)
val grid : Vdom.Attr.t

(** A pane: lifted card with vertical flex layout. *)
val panel : Vdom.Attr.t

(** Small uppercase pane heading. *)
val panel_title : Vdom.Attr.t

(** Muted one-line caption under pane content. *)
val caption : Vdom.Attr.t

(** Centered muted text used as a pane's empty/loading state. *)
val empty_note : Vdom.Attr.t

(** {2 Stat tiles} *)

(** Wrapping flex row of equal-width tiles. *)
val tile_row : Vdom.Attr.t

(** One tile: chip background, fixed min-width. *)
val tile : Vdom.Attr.t

(** Tiny uppercase tile label. *)
val tile_label : Vdom.Attr.t

(** Tile value: mono, tabular numerals. *)
val tile_value : Vdom.Attr.t

(** {2 Sparklines and histograms} *)

(** Applied to inline [<svg>] so it lays out as a block and shrinks with its
    pane rather than overflowing it. *)
val svg_block : Vdom.Attr.t

(** A chip-colored placeholder box of exactly the sparkline's size, so a pane
    keeps its layout before data arrives. *)
val sized_box : width:int -> height:int -> Vdom.Attr.t

(** Fixed-height flex row of histogram columns. *)
val hist_row : Vdom.Attr.t

(** One histogram column (bar container). *)
val hist_col : Vdom.Attr.t

(** The filled bar inside a column, [height_px] tall, accent colored. *)
val hist_bar : height_px:float -> Vdom.Attr.t

(** Row under the bars holding the lowest/highest bucket labels. *)
val hist_labels : Vdom.Attr.t

(** Fixed-height "no observations" placeholder matching {!hist_row}. *)
val hist_empty : Vdom.Attr.t

(** {2 Tables} *)

(** Scroll container capping a table's height so a flood of rows scrolls
    inside the pane instead of stretching it. *)
val table_scroll : Vdom.Attr.t

(** The table itself: full width, collapsed. *)
val table : Vdom.Attr.t

(** Sticky left-aligned header cell. *)
val th : Vdom.Attr.t

(** Sticky right-aligned header cell (numbers). *)
val th_num : Vdom.Attr.t

(** Sticky centered header over a trend column. *)
val th_trend : Vdom.Attr.t

(** Name cell: mono, left-aligned. *)
val td_name : Vdom.Attr.t

(** Numeric cell: mono, tabular numerals, right-aligned. *)
val td_num : Vdom.Attr.t

(** Trend cell, rising (amber — bad news). *)
val trend_up : Vdom.Attr.t

(** Trend cell, falling (mint — recovering). *)
val trend_down : Vdom.Attr.t

(** Trend cell, flat (muted). *)
val trend_flat : Vdom.Attr.t

(** {2 Book-depth pane} *)

(** Label + [<select>] header row. *)
val select_row : Vdom.Attr.t

(** The symbol [<select>] itself. *)
val select_input : Vdom.Attr.t

(** Chip row holding bid / spread / ask. *)
val quote_row : Vdom.Attr.t

(** Bid column (left-aligned). *)
val quote_col_left : Vdom.Attr.t

(** Spread column (centered). *)
val quote_col_center : Vdom.Attr.t

(** Ask column (right-aligned). *)
val quote_col_right : Vdom.Attr.t

(** Best-bid text (mint). *)
val quote_bid : Vdom.Attr.t

(** Best-ask text (red). *)
val quote_ask : Vdom.Attr.t

(** Spread text (muted, smaller). *)
val quote_mid : Vdom.Attr.t

(** {2 Scenario control bar}

    The band under the banner that launches scenarios (see
    {!Scenario_controls}). Each group is a grid whose title spans all
    columns; each card is a two-column grid (run button, info toggle) whose
    info panel spans both columns as a third row. *)

(** The whole band: a vertical stack of a header row and one grid per
    category, with a hairline under it separating it from the pane grid. *)
val controls_bar : Vdom.Attr.t

(** The header row: section label, running-status chip, and Stop button. *)
val controls_header : Vdom.Attr.t

(** One category's grid: a full-width title followed by its cards, which stay
    top-aligned so an expanded card does not stretch its neighbors. *)
val controls_group : Vdom.Attr.t

(** A category title spanning the group's full width, in the given color —
    [warn_hex] for the emphasized pathological group, [muted_hex] otherwise. *)
val controls_group_title : string -> Vdom.Attr.t

(** A scenario card at rest: run button and info toggle over an optional info
    panel. *)
val scenario_card : Vdom.Attr.t

(** The card of the live scenario: an accent ring and faint accent wash. *)
val scenario_card_running : Vdom.Attr.t

(** A pathological scenario's card: a faint amber wash marking the category. *)
val scenario_card_pathological : Vdom.Attr.t

(** The card's primary button — the scenario name; launches on click. *)
val scenario_run_button : Vdom.Attr.t

(** The fixed-size caret button that expands a card's info panel without
    launching it. *)
val scenario_info_toggle : Vdom.Attr.t

(** The expandable panel under a card: blurb and expected-behavior list. *)
val scenario_info_panel : Vdom.Attr.t

(** The list of predicted pane behaviors inside an info panel. *)
val expected_list : Vdom.Attr.t

(** One predicted-behavior line (its pane name is bolded by the caller). *)
val expected_item : Vdom.Attr.t

(** The Stop button. [~enabled] renders it in the danger color when something
    is running and muted (with [not-allowed]) when idle. *)
val stop_button : enabled:bool -> Vdom.Attr.t

(** The last-error line shown under the header when a launch or child exit
    failed (red text in a faint red inset). *)
val controls_error : Vdom.Attr.t
