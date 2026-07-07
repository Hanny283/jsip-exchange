open! Core
open Bonsai_web
open Jsip_types

let rate value = Float.to_string_hum ~decimals:1 value

let render_row
  ({ participant; orders_per_sec; cancels_per_sec; resting_orders } :
    Dashboard_state.Participants_view.Row.t)
  =
  {%html|
    <tr>
      <td %{Styles.td_name}>%{participant#Participant}</td>
      <td %{Styles.td_num}>#{rate orders_per_sec}</td>
      <td %{Styles.td_num}>#{rate cancels_per_sec}</td>
      <td %{Styles.td_num}>%{resting_orders#Int}</td>
    </tr>
  |}
;;

let view (rows : Dashboard_state.Participants_view.t) =
  let body =
    match rows with
    | [] ->
      {%html|
        <div %{Styles.empty_note}>no participants in window</div>
      |}
    | _ :: _ ->
      {%html|
        <div %{Styles.table_scroll}>
          <table %{Styles.table}>
            <thead>
              <tr>
                <th %{Styles.th}>participant</th>
                <th %{Styles.th_num}>orders/s</th>
                <th %{Styles.th_num}>cancels/s</th>
                <th %{Styles.th_num}>resting</th>
              </tr>
            </thead>
            <tbody>
              *{List.map rows ~f:render_row}
            </tbody>
          </table>
        </div>
      |}
  in
  {%html|<Pane.view ~title:%{"participants"}>%{body}</>|}
;;
