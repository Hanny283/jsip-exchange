open! Core
open Bonsai_web

let em_dash = "—"
let spark_width = 300
let spark_height = 44

(* The stats come from the native exchange server, where an OCaml word is 8
   bytes; rendering bytes ("94.2 MB") reads better than raw words. *)
let bytes_per_word = 8

let format_live_bytes words =
  let bytes = Float.of_int (words * bytes_per_word) in
  if Float.(bytes >= 1e9)
  then [%string "%{Float.to_string_hum ~decimals:2 (bytes /. 1e9)} GB"]
  else if Float.(bytes >= 1e6)
  then [%string "%{Float.to_string_hum ~decimals:1 (bytes /. 1e6)} MB"]
  else [%string "%{Float.to_string_hum ~decimals:0 (bytes /. 1e3)} kB"]
;;

let format_growth words_per_sec =
  let signed ~decimals value =
    Float.to_string_hum ~decimals ~explicit_plus:true value
  in
  let magnitude = Float.abs words_per_sec in
  if Float.(magnitude >= 1e6)
  then [%string "%{signed ~decimals:1 (words_per_sec /. 1e6)}M w/s"]
  else if Float.(magnitude >= 1e3)
  then [%string "%{signed ~decimals:1 (words_per_sec /. 1e3)}k w/s"]
  else [%string "%{signed ~decimals:0 words_per_sec} w/s"]
;;

let view (memory : Dashboard_state.Memory_view.t) =
  let { Dashboard_state.Memory_view.points
      ; live_words
      ; growth_words_per_sec
      }
    =
    memory
  in
  let live =
    match live_words with
    | None -> em_dash
    | Some words -> format_live_bytes words
  in
  let growth =
    match growth_words_per_sec with
    | None -> em_dash
    | Some rate -> format_growth rate
  in
  let caption =
    match points with
    | [] | [ _ ] -> "collecting samples…"
    | _ :: _ :: _ -> "live heap — last 60s"
  in
  let sparkline =
    Sparkline.view ~width:spark_width ~height:spark_height ~values:points
  in
  {%html|
    <Pane.view ~title:%{"gc / memory"}>
      <div %{Styles.tile_row}>
        <Stat_tile.view ~label:%{"live heap"} ~value:%{live} />
        <Stat_tile.view ~label:%{"growth"} ~value:%{growth} />
      </div>
      <div>
        %{sparkline}
        <div %{Styles.caption}>#{caption}</div>
      </div>
    </>
  |}
;;
