open! Core
open Bonsai_web

(* Matches the fixed height of [Styles.hist_row]; bars scale within it. *)
let bar_area_px = 56.

(* Bars for tiny counts still get a visible sliver. *)
let min_bar_px = 2.

let render_bar ~max_count (label, count) =
  let fraction = Float.of_int count /. Float.of_int max_count in
  let height_px = Float.max min_bar_px (fraction *. bar_area_px) in
  let tooltip = [%string "%{label}: %{count#Int}"] in
  {%html|
    <div %{Styles.hist_col} %{Vdom.Attr.title tooltip}>
      <div %{Styles.hist_bar ~height_px}></div>
    </div>
  |}
;;

let view ~buckets =
  match buckets with
  | [] -> {%html|<div %{Styles.hist_empty}>no observations</div>|}
  | ((first_label, _) :: _ : (string * int) list) ->
    let max_count =
      List.fold buckets ~init:1 ~f:(fun acc (_, count) -> Int.max acc count)
    in
    let bars = List.map buckets ~f:(render_bar ~max_count) in
    let last_label =
      match List.last buckets with
      | None -> first_label
      | Some (label, _) -> label
    in
    let labels =
      if String.equal first_label last_label
      then
        {%html|<div %{Styles.hist_labels}><span>#{first_label}</span></div>|}
      else
        {%html|
          <div %{Styles.hist_labels}>
            <span>#{first_label}</span>
            <span>#{last_label}</span>
          </div>
        |}
    in
    {%html|
      <div>
        <div %{Styles.hist_row}>*{bars}</div>
        %{labels}
      </div>
    |}
;;
