open! Core
open Bonsai_web

let view ~title children =
  {%html|
    <section %{Styles.panel}>
      <h2 %{Styles.panel_title}>#{title}</h2>
      *{children}
    </section>
  |}
;;
