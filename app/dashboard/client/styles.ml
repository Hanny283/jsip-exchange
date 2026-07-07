open! Core
open Bonsai_web

(* Palette. Keep every color here: the [_hex] strings below are the single
   source of truth, exported for SVG strokes; the attribute tokens bake the
   same values into inline styles. *)
let page_bg_hex = "#0f1115"
let panel_bg_hex = "#171a21"
let chip_bg_hex = "#1f2430"
let border_hex = "#262b36"
let text_hex = "#e6e9ef"
let muted_hex = "#8b93a7"
let accent_hex = "#5ac8fa"
let warn_hex = "#ffb454"
let bad_hex = "#ff6b6b"
let ok_hex = "#3dd68c"

(* Font stacks. Numeric cells use the mono stack plus tabular figures so
   columns of numbers line up as they tick. *)
let sans_font =
  "font-family: system-ui, -apple-system, 'Segoe UI', sans-serif"
;;

let mono_font =
  "font-family: ui-monospace, 'SF Mono', Menlo, Consolas, monospace"
;;

let tabular = "font-variant-numeric: tabular-nums"

(* All tokens are plain [style="..."] attributes: this project has no
   ppx_css, and ppx_html's [style=] attribute desugars to it, so panes
   interpolate these as whole attributes instead. *)
let style props = Vdom.Attr.create "style" (String.concat props ~sep:"; ")

(* Page chrome ------------------------------------------------------- *)

let page =
  style
    [ "min-height: 100vh"
    ; [%string "background: %{page_bg_hex}"]
    ; [%string "color: %{text_hex}"]
    ; sans_font
    ; "font-size: 13px"
    ; "line-height: 1.45"
    ; "color-scheme: dark"
    ]
;;

let banner =
  style
    [ "display: flex"
    ; "align-items: center"
    ; "justify-content: space-between"
    ; "gap: 16px"
    ; "padding: 10px 16px"
    ; "background: #12151b"
    ; [%string "border-bottom: 1px solid %{chip_bg_hex}"]
    ; "position: sticky"
    ; "top: 0"
    ; "z-index: 10"
    ]
;;

let banner_left =
  style [ "display: flex"; "align-items: baseline"; "gap: 10px" ]
;;

let banner_product =
  style
    [ "font-size: 13px"
    ; "font-weight: 650"
    ; "letter-spacing: 0.08em"
    ; "text-transform: uppercase"
    ]
;;

let banner_note =
  style [ [%string "color: %{muted_hex}"]; "font-size: 12px" ]
;;

let status_chip =
  style
    [ "display: inline-flex"
    ; "align-items: center"
    ; "gap: 7px"
    ; "padding: 3px 12px"
    ; [%string "background: %{chip_bg_hex}"]
    ; "border-radius: 999px"
    ; "font-size: 12px"
    ; "min-width: 0"
    ]
;;

let dot color_hex =
  style
    [ "width: 8px"
    ; "height: 8px"
    ; "border-radius: 50%"
    ; "flex: none"
    ; [%string "background: %{color_hex}"]
    ]
;;

let dot_muted = dot muted_hex
let dot_ok = dot ok_hex
let dot_bad = dot bad_hex

let error_detail =
  style
    [ [%string "color: %{muted_hex}"]
    ; "max-width: 48ch"
    ; "overflow: hidden"
    ; "text-overflow: ellipsis"
    ; "white-space: nowrap"
    ]
;;

(* Pane grid and panels ---------------------------------------------- *)

let grid =
  style
    [ "display: grid"
    ; "gap: 12px"
    ; "grid-template-columns: repeat(auto-fit, minmax(340px, 1fr))"
    ; "padding: 16px"
    ; "align-items: start"
    ]
;;

let panel =
  style
    [ [%string "background: %{panel_bg_hex}"]
    ; [%string "border: 1px solid %{border_hex}"]
    ; "border-radius: 8px"
    ; "padding: 12px 14px"
    ; "display: flex"
    ; "flex-direction: column"
    ; "gap: 10px"
    ; "box-shadow: 0 1px 1px rgba(0,0,0,0.35), 0 2px 4px rgba(0,0,0,0.25)"
    ; "min-width: 0"
    ]
;;

let panel_title =
  style
    [ "margin: 0"
    ; "font-size: 11px"
    ; "font-weight: 600"
    ; "letter-spacing: 0.06em"
    ; "text-transform: uppercase"
    ; [%string "color: %{muted_hex}"]
    ]
;;

let caption =
  style
    [ [%string "color: %{muted_hex}"]; "font-size: 11px"; "margin-top: 4px" ]
;;

let empty_note =
  style
    [ [%string "color: %{muted_hex}"]
    ; "font-size: 12px"
    ; "text-align: center"
    ; "padding: 18px 0"
    ]
;;

(* Stat tiles --------------------------------------------------------- *)

let tile_row = style [ "display: flex"; "flex-wrap: wrap"; "gap: 8px" ]

let tile =
  style
    [ "flex: 1 1 0"
    ; "min-width: 88px"
    ; [%string "background: %{chip_bg_hex}"]
    ; "border-radius: 6px"
    ; "padding: 7px 10px"
    ; "display: flex"
    ; "flex-direction: column"
    ; "gap: 2px"
    ]
;;

let tile_label =
  style
    [ "font-size: 10px"
    ; "font-weight: 600"
    ; "letter-spacing: 0.05em"
    ; "text-transform: uppercase"
    ; [%string "color: %{muted_hex}"]
    ; "white-space: nowrap"
    ]
;;

let tile_value =
  style [ mono_font; tabular; "font-size: 15px"; "white-space: nowrap" ]
;;

(* Sparklines and histograms ------------------------------------------ *)

let svg_block = style [ "display: block"; "max-width: 100%" ]

let sized_box ~width ~height =
  style
    [ [%string "width: %{width#Int}px"]
    ; [%string "height: %{height#Int}px"]
    ; "max-width: 100%"
    ; [%string "background: %{chip_bg_hex}"]
    ; "border-radius: 4px"
    ]
;;

let hist_row =
  style
    [ "display: flex"; "align-items: flex-end"; "gap: 2px"; "height: 56px" ]
;;

let hist_col =
  style [ "flex: 1 1 0"; "min-width: 4px"; "height: 100%"; "display: flex" ]
;;

let hist_bar ~height_px =
  style
    [ "width: 100%"
    ; "align-self: flex-end"
    ; [%string "height: %{Float.to_string_hum ~decimals:1 height_px}px"]
    ; [%string "background: %{accent_hex}"]
    ; "opacity: 0.8"
    ; "border-radius: 2px 2px 0 0"
    ]
;;

let hist_labels =
  style
    [ "display: flex"
    ; "justify-content: space-between"
    ; [%string "color: %{muted_hex}"]
    ; "font-size: 10px"
    ; mono_font
    ; tabular
    ; "margin-top: 2px"
    ]
;;

let hist_empty =
  style
    [ "height: 56px"
    ; "display: flex"
    ; "align-items: center"
    ; "justify-content: center"
    ; [%string "background: %{chip_bg_hex}"]
    ; "border-radius: 4px"
    ; [%string "color: %{muted_hex}"]
    ; "font-size: 12px"
    ]
;;

(* Tables -------------------------------------------------------------- *)

let table_scroll =
  style [ "max-height: 230px"; "overflow-y: auto"; "scrollbar-width: thin" ]
;;

let table =
  style [ "width: 100%"; "border-collapse: collapse"; "font-size: 12px" ]
;;

let th_base =
  [ "position: sticky"
  ; "top: 0"
  ; [%string "background: %{panel_bg_hex}"]
  ; "font-size: 10px"
  ; "font-weight: 600"
  ; "letter-spacing: 0.05em"
  ; "text-transform: uppercase"
  ; [%string "color: %{muted_hex}"]
  ; "padding: 0 8px 4px 0"
  ]
;;

let th = style (th_base @ [ "text-align: left" ])
let th_num = style (th_base @ [ "text-align: right" ])
let th_trend = style (th_base @ [ "text-align: center"; "width: 34px" ])

let td_base =
  [ "padding: 3px 8px 3px 0"
  ; [%string "border-top: 1px solid %{chip_bg_hex}"]
  ; "white-space: nowrap"
  ]
;;

let td_name =
  style (td_base @ [ mono_font; "font-size: 11.5px"; "text-align: left" ])
;;

let td_num = style (td_base @ [ mono_font; tabular; "text-align: right" ])
let trend_base = [ "width: 34px"; "text-align: center"; "font-size: 10px" ]

let trend_up =
  style (td_base @ trend_base @ [ [%string "color: %{warn_hex}"] ])
;;

let trend_down =
  style (td_base @ trend_base @ [ [%string "color: %{ok_hex}"] ])
;;

let trend_flat =
  style (td_base @ trend_base @ [ [%string "color: %{muted_hex}"] ])
;;

(* Book-depth pane ------------------------------------------------------ *)

let select_row =
  style
    [ "display: flex"
    ; "align-items: center"
    ; "justify-content: space-between"
    ; "gap: 8px"
    ]
;;

let select_input =
  style
    [ [%string "background: %{chip_bg_hex}"]
    ; [%string "color: %{text_hex}"]
    ; [%string "border: 1px solid %{border_hex}"]
    ; "border-radius: 6px"
    ; "padding: 4px 8px"
    ; "font-size: 12px"
    ; mono_font
    ]
;;

let quote_row =
  style
    [ "display: flex"
    ; "align-items: center"
    ; "justify-content: space-between"
    ; "gap: 12px"
    ; [%string "background: %{chip_bg_hex}"]
    ; "border-radius: 6px"
    ; "padding: 8px 12px"
    ]
;;

let quote_col align =
  style [ "display: flex"; "flex-direction: column"; "gap: 2px"; align ]
;;

let quote_col_left = quote_col "align-items: flex-start"
let quote_col_center = quote_col "align-items: center"
let quote_col_right = quote_col "align-items: flex-end"

let quote_value color_hex =
  [ mono_font
  ; tabular
  ; "font-size: 14px"
  ; "white-space: nowrap"
  ; [%string "color: %{color_hex}"]
  ]
;;

let quote_bid = style (quote_value ok_hex)
let quote_ask = style (quote_value bad_hex)
let quote_mid = style (quote_value muted_hex @ [ "font-size: 12px" ])
