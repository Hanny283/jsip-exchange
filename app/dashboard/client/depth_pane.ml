open! Core
open Bonsai_web
open Bonsai.Let_syntax
open Jsip_types

let em_dash = "—"
let title = "book depth"

let level_or_dash = function
  | None -> em_dash
  | Some level -> Level.to_string level
;;

let quote_block (bbo : Bbo.t option) =
  let bid, ask, spread =
    match bbo with
    | None -> em_dash, em_dash, em_dash
    | Some bbo ->
      let spread =
        match Bbo.spread bbo with
        | None -> em_dash
        | Some price -> Price.to_string price
      in
      level_or_dash bbo.bid, level_or_dash bbo.ask, spread
  in
  {%html|
    <div %{Styles.quote_row}>
      <div %{Styles.quote_col_left}>
        <div %{Styles.tile_label}>bid</div>
        <div %{Styles.quote_bid}>#{bid}</div>
      </div>
      <div %{Styles.quote_col_center}>
        <div %{Styles.tile_label}>spread</div>
        <div %{Styles.quote_mid}>#{spread}</div>
      </div>
      <div %{Styles.quote_col_right}>
        <div %{Styles.tile_label}>ask</div>
        <div %{Styles.quote_ask}>#{ask}</div>
      </div>
    </div>
  |}
;;

let depth_body (depth : Dashboard_state.Depth_view.t option) ~symbol =
  match depth with
  | None ->
    {%html|
      <div %{Styles.empty_note}>
        no book for %{symbol#Symbol} in the latest sample
      </div>
    |}
  | Some
      { Dashboard_state.Depth_view.bbo
      ; bid_size
      ; bid_orders
      ; ask_size
      ; ask_orders
      } ->
    let quote = quote_block bbo in
    let bid_size = Size.to_string bid_size in
    let ask_size = Size.to_string ask_size in
    let bid_orders = Int.to_string bid_orders in
    let ask_orders = Int.to_string ask_orders in
    {%html|
      <>
        %{quote}
        <div %{Styles.tile_row}>
          <Stat_tile.view ~label:%{"bid size"} ~value:%{bid_size} />
          <Stat_tile.view ~label:%{"bid orders"} ~value:%{bid_orders} />
          <Stat_tile.view ~label:%{"ask size"} ~value:%{ask_size} />
          <Stat_tile.view ~label:%{"ask orders"} ~value:%{ask_orders} />
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
    (* Option values round-trip through [Symbol.to_string], so [find]
       normally succeeds; matching (rather than [Symbol.of_string]) keeps
       this handler total and raise-free. *)
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
          <div>#{em_dash}</div>
          <div>no books in window yet</div>
        </div>
      </>
    |}
  | Some symbol ->
    let select = select_block ~symbols ~symbol ~set_selected in
    let body =
      depth_body (Dashboard_state.depth_view state ~symbol) ~symbol
    in
    {%html|
      <Pane.view ~title>
        %{select}
        %{body}
      </>
    |}
;;
