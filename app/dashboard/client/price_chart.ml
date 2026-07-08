open! Core
open Bonsai_web

(* Breathing room inside the viewBox so a stroke at the series extremes isn't
   clipped, matching {!Sparkline}. *)
let inset = 2.
let stroke_width = 1.5

(* Dash pattern (user units) for the fundamental line: a reference value,
   drawn lighter than the solid market line. *)
let fundamental_dash = [ 5.; 4. ]

(* The plotted vertices of one series: x by sample index, y already scaled. A
   [None] sample contributes no vertex, so the polyline bridges the gap. *)
let series_points values ~x_of ~y_of =
  List.filter_mapi values ~f:(fun i value ->
    Option.map value ~f:(fun value -> x_of i, y_of value))
;;

(* A polyline needs two vertices to paint a segment; a lone point draws
   nothing. So the chart is worth drawing only when some series has two or
   more plotted points -- otherwise the placeholder box holds the pane's
   layout. A >=2-across-both-series test would let one point per line slip
   through and render blank. *)
let is_drawable series = List.count series ~f:Option.is_some >= 2

let view ~width ~height ~market ~fundamental =
  match is_drawable market || is_drawable fundamental with
  | false -> {%html|<div %{Styles.sized_box ~width ~height}></div>|}
  | true ->
    let w = Float.of_int width in
    let h = Float.of_int height in
    (* Scale over every plotted value of both series so the two lines share
       one y-axis; the count spans the whole window so they share the x-axis
       too. [present] is non-empty here because some series has >=2 points. *)
    let lo, hi =
      List.filter_opt (market @ fundamental)
      |> List.fold
           ~init:(Float.infinity, Float.neg_infinity)
           ~f:(fun (lo, hi) value -> Float.min lo value, Float.max hi value)
    in
    let count = Int.max (List.length market) (List.length fundamental) in
    let x_of i =
      if count <= 1
      then inset
      else
        inset
        +. (Float.of_int i /. Float.of_int (count - 1) *. (w -. (2. *. inset))
           )
    in
    let y_of value =
      (* A flat series draws as a centered line. *)
      if Float.(hi <= lo)
      then h /. 2.
      else inset +. ((hi -. value) /. (hi -. lo) *. (h -. (2. *. inset)))
    in
    let viewbox =
      Virtual_dom_svg.Attr.viewbox ~min_x:0. ~min_y:0. ~width:w ~height:h
    in
    let no_fill = Vdom.Attr.create "fill" "none" in
    let open Virtual_dom_svg.Html_syntax in
    let line ~color ~dash values =
      let dash_attr =
        match dash with
        | [] -> Vdom.Attr.empty
        | _ :: _ -> Virtual_dom_svg.Attr.stroke_dasharray dash
      in
      {%html|
        <polyline
          %{Virtual_dom_svg.Attr.points (series_points values ~x_of ~y_of)}
          %{Virtual_dom_svg.Attr.stroke (`Hex color)}
          %{dash_attr}
          %{Virtual_dom_svg.Attr.stroke_width stroke_width}
          %{Virtual_dom_svg.Attr.stroke_linecap `Round}
          %{no_fill}></polyline>
      |}
    in
    (* Fundamental first so the solid market line reads on top. *)
    let fundamental_line =
      line ~color:Styles.muted_hex ~dash:fundamental_dash fundamental
    in
    let market_line = line ~color:Styles.accent_hex ~dash:[] market in
    {%html|
      <svg
        %{viewbox}
        %{Virtual_dom_svg.Attr.width w}
        %{Virtual_dom_svg.Attr.height h}
        %{Styles.svg_block}>
        %{fundamental_line}
        %{market_line}
      </svg>
    |}
;;
