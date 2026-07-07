open! Core
open Bonsai_web

(* Breathing room inside the viewBox so the stroke doesn't clip at the series
   extremes. *)
let inset = 2.
let stroke_width = 1.5

let view ~width ~height ~values =
  match values with
  | [] | [ _ ] -> {%html|<div %{Styles.sized_box ~width ~height}></div>|}
  | first :: (_ :: _ as rest) ->
    let w = Float.of_int width in
    let h = Float.of_int height in
    let lo, hi =
      List.fold rest ~init:(first, first) ~f:(fun (lo, hi) value ->
        Float.min lo value, Float.max hi value)
    in
    let count = 1 + List.length rest in
    let x_step = (w -. (2. *. inset)) /. Float.of_int (count - 1) in
    let y_of value =
      (* A constant series draws as a centered flat line. *)
      if Float.(hi <= lo)
      then h /. 2.
      else inset +. ((hi -. value) /. (hi -. lo) *. (h -. (2. *. inset)))
    in
    let points =
      List.mapi values ~f:(fun i value ->
        inset +. (Float.of_int i *. x_step), y_of value)
    in
    let viewbox =
      Virtual_dom_svg.Attr.viewbox ~min_x:0. ~min_y:0. ~width:w ~height:h
    in
    let stroke = Virtual_dom_svg.Attr.stroke (`Hex Styles.accent_hex) in
    let no_fill = Vdom.Attr.create "fill" "none" in
    let open Virtual_dom_svg.Html_syntax in
    {%html|
      <svg
        %{viewbox}
        %{Virtual_dom_svg.Attr.width w}
        %{Virtual_dom_svg.Attr.height h}
        %{Styles.svg_block}>
        <polyline
          %{Virtual_dom_svg.Attr.points points}
          %{stroke}
          %{Virtual_dom_svg.Attr.stroke_width stroke_width}
          %{Virtual_dom_svg.Attr.stroke_linecap `Round}
          %{no_fill}></polyline>
      </svg>
    |}
;;
