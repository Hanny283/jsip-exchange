open! Core
open Bonsai_web
open Bonsai.Let_syntax
open Jsip_dashboard_protocol
module Category = Scenario_control.Category
module Scenario_info = Scenario_control.Scenario_info
module Run_request = Scenario_control.Run_request
module Run_state = Scenario_control.Run_state

(* Poll the live status often — it changes as children start and exit. The
   catalog is static, so fetch it once with [poll_until_ok]: it retries
   promptly until the first list arrives (even if the first attempt races a
   just-opened websocket) and then stops, instead of leaving the bar stuck on
   "loading…" until a slow repoll. *)
let status_poll_every = Time_ns.Span.of_sec 1.
let list_retry_every = Time_ns.Span.of_sec 1.

(* Pathological first and emphasized: those are the pathologies the dashboard
   exists to make visible. *)
let category_order = [ Category.Pathological; Market_event; Baseline ]

let category_label : Category.t -> string = function
  | Baseline -> "baseline"
  | Market_event -> "market event"
  | Pathological -> "pathological"
;;

let category_title_hex : Category.t -> string = function
  | Pathological -> Styles.warn_hex
  | Baseline | Market_event -> Styles.muted_hex
;;

(* Bold the pane name before the first colon so a line like "Memory: flat …"
   scans as a labelled prediction against the matching pane. Lines without a
   colon are rendered verbatim; either way this never raises. *)
let expected_item text =
  match String.lsplit2 text ~on:':' with
  | None -> {%html|<li %{Styles.expected_item}>#{text}</li>|}
  | Some (pane, rest) ->
    let rest = ": " ^ String.lstrip rest in
    {%html|
      <li %{Styles.expected_item}><strong>#{pane}</strong>#{rest}</li>
    |}
;;

let info_panel (info : Scenario_info.t) =
  {%html|
    <div %{Styles.scenario_info_panel}>
      <div>#{info.blurb}</div>
      <div %{Styles.tile_label}>expected on the panels</div>
      <ul %{Styles.expected_list}>
        *{List.map info.expected ~f:expected_item}
      </ul>
    </div>
  |}
;;

let render_card ~(info : Scenario_info.t) ~is_running ~is_open ~run ~toggle =
  let name = info.name in
  let card_style =
    match is_running with
    | true -> Styles.scenario_card_running
    | false ->
      (match info.category with
       | Pathological -> Styles.scenario_card_pathological
       | Baseline | Market_event -> Styles.scenario_card)
  in
  let live =
    match is_running with
    | true -> Some {%html|<span %{Styles.dot_ok}></span>|}
    | false -> None
  in
  let caret, toggle_title =
    match is_open with
    | true -> "▾", "hide details"
    | false -> "▸", "show details"
  in
  let panel =
    match is_open with true -> Some (info_panel info) | false -> None
  in
  {%html|
    <div %{card_style}>
      <button
        %{Styles.scenario_run_button}
        %{Vdom.Attr.title "launch this scenario"}
        on_click=%{fun _ -> run}>
        ?{live}
        <span>#{name}</span>
      </button>
      <button
        %{Styles.scenario_info_toggle}
        %{Vdom.Attr.title toggle_title}
        on_click=%{fun _ -> toggle}>
        #{caret}
      </button>
      ?{panel}
    </div>
  |}
;;

let render_group ~(category : Category.t) ~cards =
  let title = String.uppercase (category_label category) in
  {%html|
    <div %{Styles.controls_group}>
      <div %{Styles.controls_group_title (category_title_hex category)}>
        #{title}
      </div>
      *{cards}
    </div>
  |}
;;

let running_chip (running : Run_state.Running.t option) =
  match running with
  | None ->
    {%html|
      <span %{Styles.status_chip}>
        <span %{Styles.dot_muted}></span>
        idle — pick a scenario to launch
      </span>
    |}
  | Some { name; seed } ->
    let label = [%string "running: %{name}  (seed %{seed#Int})"] in
    {%html|
      <span %{Styles.status_chip}>
        <span %{Styles.dot_ok}></span>
        #{label}
      </span>
    |}
;;

let header ~running ~stop =
  let enabled = Option.is_some running in
  let disabled_attr =
    match enabled with true -> None | false -> Some Vdom.Attr.disabled
  in
  {%html|
    <div %{Styles.controls_header}>
      <h2 %{Styles.panel_title}>scenarios</h2>
      %{running_chip running}
      <button
        %{Styles.stop_button ~enabled}
        ?{disabled_attr}
        on_click=%{fun _ -> stop}>
        stop
      </button>
    </div>
  |}
;;

(* The single info panel that is treated as open: the one the user last
   toggled, or — when nothing is toggled — the running scenario's, so its
   predictions sit open next to the live panes for comparison. *)
let effective_expanded ~expanded ~(running : Run_state.Running.t option) =
  match expanded with
  | Some name -> Some name
  | None -> Option.map running ~f:(fun running -> running.name)
;;

let group_nodes
  ~scenarios
  ~(running : Run_state.Running.t option)
  ~expanded
  ~set_expanded
  ~dispatch_run
  =
  let expanded = effective_expanded ~expanded ~running in
  List.filter_map category_order ~f:(fun category ->
    let infos =
      List.filter scenarios ~f:(fun (info : Scenario_info.t) ->
        Category.equal info.category category)
    in
    match infos with
    | [] -> None
    | _ :: _ ->
      let cards =
        List.map infos ~f:(fun (info : Scenario_info.t) ->
          let is_running =
            Option.exists running ~f:(fun running ->
              String.equal running.name info.name)
          in
          let is_open = Option.exists expanded ~f:(String.equal info.name) in
          (* Launching also opens this card so its predictions are up as the
             panes react; the status poll picks up the new running state. *)
          let run =
            let%bind.Effect () = set_expanded (Some info.name) in
            let%bind.Effect (_ : unit Or_error.t Or_error.t) =
              dispatch_run { Run_request.name = info.name; seed = 0 }
            in
            Effect.Ignore
          in
          let toggle =
            set_expanded
              (match is_open with true -> None | false -> Some info.name)
          in
          render_card ~info ~is_running ~is_open ~run ~toggle)
      in
      Some (render_group ~category ~cards))
;;

let view
  ~scenarios
  ~running
  ~last_error
  ~expanded
  ~set_expanded
  ~dispatch_run
  ~dispatch_stop
  =
  let stop =
    let%bind.Effect (_ : unit Or_error.t Or_error.t) = dispatch_stop () in
    Effect.Ignore
  in
  let error_node =
    Option.map last_error ~f:(fun message ->
      {%html|
        <div %{Styles.controls_error}>
          <span>⚠</span>
          <span>#{message}</span>
        </div>
      |})
  in
  let body =
    match scenarios with
    | None -> [ {%html|<div %{Styles.empty_note}>loading scenarios…</div>|} ]
    | Some [] ->
      [ {%html|<div %{Styles.empty_note}>no scenarios available</div>|} ]
    | Some (_ :: _ as scenarios) ->
      group_nodes ~scenarios ~running ~expanded ~set_expanded ~dispatch_run
  in
  {%html|
    <section %{Styles.controls_bar}>
      %{header ~running ~stop}
      ?{error_node}
      *{body}
    </section>
  |}
;;

let component (local_ graph) =
  let status =
    Rpc_effect.Rpc.poll
      Scenario_control.scenario_status_rpc
      ~equal_query:[%equal: unit]
      ~every:(Bonsai.return status_poll_every)
      ~output_type:Response_state
      (Bonsai.return ())
      graph
  in
  let scenarios =
    Rpc_effect.Rpc.poll_until_ok
      Scenario_control.list_scenarios_rpc
      ~equal_query:[%equal: unit]
      ~retry_interval:(Bonsai.return list_retry_every)
      ~output_type:Last_ok_response
      (Bonsai.return ())
      graph
  in
  let dispatch_run =
    Rpc_effect.Rpc.dispatcher Scenario_control.run_scenario_rpc graph
  in
  let dispatch_stop =
    Rpc_effect.Rpc.dispatcher Scenario_control.stop_scenario_rpc graph
  in
  let expanded, set_expanded = Bonsai.state (None : string option) graph in
  let%arr status
  and scenarios
  and dispatch_run
  and dispatch_stop
  and expanded
  and set_expanded in
  (* [Response_state] keeps the last good status on screen while a poll is in
     flight or erroring, so the control bar does not flicker to "idle". *)
  let run_state =
    match (status : Run_state.t Rpc_effect.Poll_result.Response_state.t) with
    | No_response_yet -> None
    | Ok run_state -> Some run_state
    | Error { last_ok_response; error = _ } -> last_ok_response
  in
  let running =
    Option.bind run_state ~f:(fun (run_state : Run_state.t) ->
      run_state.running)
  in
  let last_error =
    Option.bind run_state ~f:(fun (run_state : Run_state.t) ->
      run_state.last_error)
  in
  view
    ~scenarios
    ~running
    ~last_error
    ~expanded
    ~set_expanded
    ~dispatch_run
    ~dispatch_stop
;;
