open! Core
open Bonsai_web

let status_chip (status : Samples_subscription.Status.t) =
  match status with
  | Waiting ->
    {%html|
      <span %{Styles.status_chip}>
        <span %{Styles.dot_muted}></span>
        connecting — waiting for first sample
      </span>
    |}
  | Connected ->
    {%html|
      <span %{Styles.status_chip}>
        <span %{Styles.dot_ok}></span>
        live
      </span>
    |}
  | Failing error ->
    let detail = Error.to_string_hum error in
    {%html|
      <span %{Styles.status_chip}>
        <span %{Styles.dot_bad}></span>
        disconnected
        <span %{Styles.error_detail} %{Vdom.Attr.title detail}>
          #{detail}
        </span>
      </span>
    |}
;;

let view ~reset status =
  {%html|
    <header %{Styles.banner}>
      <div %{Styles.banner_left}>
        <span %{Styles.banner_product}>JSIP Exchange</span>
        <span %{Styles.banner_note}>operations dashboard</span>
      </div>
      <div %{Styles.banner_right}>
        <button %{Styles.reset_button} on_click=%{fun _ -> reset}>
          Reset
        </button>
        %{status_chip status}
      </div>
    </header>
  |}
;;
