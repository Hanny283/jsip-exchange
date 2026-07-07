open! Core
open Bonsai_web

let spark_width = 300
let spark_height = 44

let span_or_dash = function
  | None -> "-"
  | Some span -> Time_ns.Span.to_string span
;;

let view (loop : Dashboard_state.Loop_view.t) =
  let { Dashboard_state.Loop_view.p50
      ; p99
      ; max_gap_points
      ; iterations_per_sec
      }
    =
    loop
  in
  let iterations =
    match iterations_per_sec with
    | None -> "-"
    | Some rate -> Float.to_string_hum ~decimals:1 rate
  in
  let caption =
    match max_gap_points with
    | [] | [ _ ] -> "collecting samples…"
    | _ :: _ :: _ -> "worst gap per sample (seconds)"
  in
  let sparkline =
    Sparkline.view
      ~width:spark_width
      ~height:spark_height
      ~values:max_gap_points
  in
  {%html|
    <Pane.view ~title:%{"matching loop"}>
      <div %{Styles.tile_row}>
        <Stat_tile.view ~label:%{"gap p50"} ~value:%{span_or_dash p50} />
        <Stat_tile.view ~label:%{"gap p99"} ~value:%{span_or_dash p99} />
        <Stat_tile.view ~label:%{"iterations/s"} ~value:%{iterations} />
      </div>
      <div>
        %{sparkline}
        <div %{Styles.caption}>#{caption}</div>
      </div>
    </>
  |}
;;
