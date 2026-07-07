open! Core
open Bonsai_web

let trend_cell (trend : Dashboard_state.Trend.t) =
  match trend with
  | Rising ->
    {%html|
      <td %{Styles.trend_up} %{Vdom.Attr.title "rising vs ~10s ago"}>
        ▲
      </td>
    |}
  | Falling ->
    {%html|
      <td %{Styles.trend_down} %{Vdom.Attr.title "falling vs ~10s ago"}>
        ▼
      </td>
    |}
  | Flat -> {%html|<td %{Styles.trend_flat}>–</td>|}
;;

let render_row
  ({ name; length; trend } : Dashboard_state.Occupancy_view.Row.t)
  =
  {%html|
    <tr>
      <td %{Styles.td_name}>#{name}</td>
      <td %{Styles.td_num}>%{length#Int}</td>
      %{trend_cell trend}
    </tr>
  |}
;;

let view (rows : Dashboard_state.Occupancy_view.t) =
  let body =
    match rows with
    | [] ->
      {%html|
        <div %{Styles.empty_note}>no pipes reported yet</div>
      |}
    | _ :: _ ->
      {%html|
        <div %{Styles.table_scroll}>
          <table %{Styles.table}>
            <thead>
              <tr>
                <th %{Styles.th}>pipe</th>
                <th %{Styles.th_num}>depth</th>
                <th %{Styles.th_trend}>10s</th>
              </tr>
            </thead>
            <tbody>
              *{List.map rows ~f:render_row}
            </tbody>
          </table>
        </div>
      |}
  in
  {%html|<Pane.view ~title:%{"pipe occupancy"}>%{body}</>|}
;;
