open! Core
open Bonsai_web

let em_dash = "—"

let span_or_dash = function
  | None -> em_dash
  | Some span -> Time_ns.Span.to_string span
;;

let view ~title (latency : Dashboard_state.Latency_view.t) =
  let { Dashboard_state.Latency_view.p50; p90; p99; buckets; total } =
    latency
  in
  let caption =
    match total with
    | 0 -> "waiting for commands…"
    | total -> [%string "%{total#Int} observations in window"]
  in
  let histogram = Histogram_bars.view ~buckets in
  {%html|
    <Pane.view ~title>
      <div %{Styles.tile_row}>
        <Stat_tile.view ~label:%{"p50"} ~value:%{span_or_dash p50} />
        <Stat_tile.view ~label:%{"p90"} ~value:%{span_or_dash p90} />
        <Stat_tile.view ~label:%{"p99"} ~value:%{span_or_dash p99} />
      </div>
      <div>
        %{histogram}
        <div %{Styles.caption}>#{caption}</div>
      </div>
    </>
  |}
;;
