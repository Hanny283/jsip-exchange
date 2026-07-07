open! Core
open Bonsai_web

let view ~label ~value () =
  {%html|
    <div %{Styles.tile}>
      <div %{Styles.tile_label}>#{label}</div>
      <div %{Styles.tile_value}>#{value}</div>
    </div>
  |}
;;
