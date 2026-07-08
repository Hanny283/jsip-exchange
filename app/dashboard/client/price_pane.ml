open! Core
open Bonsai_web
open Bonsai.Let_syntax
open Jsip_types

let title = "price over time"
let chart_width = 300
let chart_height = 96

let dollars (price : Price.t) =
  Float.of_int (Price.to_int_cents price) /. 100.
;;

let price_body (points : Dashboard_state.Price_view.t) ~symbol =
  match points with
  | [] ->
    {%html|
      <div %{Styles.empty_note}>
        no prices for %{symbol#Symbol} in window yet
      </div>
    |}
  | _ :: _ ->
    let market =
      List.map points ~f:(fun (p : Dashboard_state.Price_view.Point.t) ->
        Option.map p.market ~f:dollars)
    in
    let fundamental =
      List.map points ~f:(fun (p : Dashboard_state.Price_view.Point.t) ->
        Option.map p.fundamental ~f:dollars)
    in
    let latest : Dashboard_state.Price_view.Point.t = List.last_exn points in
    let show = function
      | None -> "-"
      | Some price -> Price.to_string price
    in
    let market_str = show latest.market in
    let fundamental_str = show latest.fundamental in
    let chart =
      Price_chart.view
        ~width:chart_width
        ~height:chart_height
        ~market
        ~fundamental
    in
    (* Legend for the two lines; the accent/muted colors match the chart
       strokes. Keyed on the same "some series has >=2 points" test the chart
       uses to draw, so the legend never labels an empty placeholder box. *)
    let drawable series = List.count series ~f:Option.is_some >= 2 in
    let caption =
      if drawable market || drawable fundamental
      then "solid = market mid  ·  dashed = fundamental"
      else "collecting samples…"
    in
    {%html|
      <>
        <div %{Styles.tile_row}>
          <Stat_tile.view ~label:%{"market (mid)"} ~value:%{market_str} />
          <Stat_tile.view ~label:%{"fundamental"} ~value:%{fundamental_str} />
        </div>
        <div>
          %{chart}
          <div %{Styles.caption}>#{caption}</div>
        </div>
      </>
    |}
;;

let select_block ~symbols ~symbol ~set_selected =
  let options =
    List.map symbols ~f:(fun sym ->
      let name = Symbol.to_string sym in
      {%html|<option value=%{name}>#{name}</option>|})
  in
  let on_change (_ : _ Js_of_ocaml.Js.t) value =
    (* Values round-trip through [Symbol.to_string], so [find] normally
       succeeds; matching (rather than [Symbol.of_string]) keeps this handler
       total and raise-free. *)
    match
      List.find symbols ~f:(fun sym ->
        String.equal (Symbol.to_string sym) value)
    with
    | Some sym -> set_selected (Some sym)
    | None -> Effect.Ignore
  in
  {%html|
    <div %{Styles.select_row}>
      <span %{Styles.tile_label}>symbol</span>
      <select
        %{Styles.select_input}
        %{Vdom.Attr.value_prop (Symbol.to_string symbol)}
        on_change=%{on_change}>
        *{options}
      </select>
    </div>
  |}
;;

let component ~(state : Dashboard_state.t Bonsai.t) (local_ graph) =
  let selected, set_selected = Bonsai.state (None : Symbol.t option) graph in
  let%arr state and selected and set_selected in
  let symbols = Dashboard_state.symbols state in
  (* The selection survives symbols coming and going: fall back to the first
     symbol while the selected one is absent from the window. *)
  let effective =
    match selected with
    | Some symbol when List.mem symbols symbol ~equal:Symbol.equal ->
      Some symbol
    | Some _ | None -> List.hd symbols
  in
  match effective with
  | None ->
    {%html|
      <Pane.view ~title>
        <div %{Styles.empty_note}>
          <div>#{"-"}</div>
          <div>no prices in window yet</div>
        </div>
      </>
    |}
  | Some symbol ->
    let select = select_block ~symbols ~symbol ~set_selected in
    let body =
      price_body (Dashboard_state.price_view state ~symbol) ~symbol
    in
    {%html|
      <Pane.view ~title>
        %{select}
        %{body}
      </>
    |}
;;
