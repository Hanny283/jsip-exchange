open! Core
open Bonsai_web
open Bonsai.Let_syntax

let app (local_ graph) =
  let state, status, reset = Samples_subscription.component graph in
  (* Each pane derives its view record as its own [Bonsai.t] behind an
     equality cutoff: the sample window changes every second, but a pane's
     vdom is rebuilt only when the numbers it renders actually changed (e.g.
     the depth pane's book moves constantly while the latency percentiles
     hold still). *)
  let pane_node ~equal ~derive ~view =
    let record =
      Bonsai.cutoff
        (let%arr state in
         derive state)
        ~equal
    in
    let%arr record in
    view record
  in
  let submit_latency =
    pane_node
      ~equal:[%equal: Dashboard_state.Latency_view.t]
      ~derive:Dashboard_state.submit_latency_view
      ~view:(Latency_pane.view ~title:"submit latency")
  in
  let cancel_latency =
    pane_node
      ~equal:[%equal: Dashboard_state.Latency_view.t]
      ~derive:Dashboard_state.cancel_latency_view
      ~view:(Latency_pane.view ~title:"cancel latency")
  in
  let loop =
    pane_node
      ~equal:[%equal: Dashboard_state.Loop_view.t]
      ~derive:Dashboard_state.loop_view
      ~view:Loop_pane.view
  in
  let occupancy =
    pane_node
      ~equal:[%equal: Dashboard_state.Occupancy_view.t]
      ~derive:Dashboard_state.occupancy_view
      ~view:Occupancy_pane.view
  in
  let memory =
    pane_node
      ~equal:[%equal: Dashboard_state.Memory_view.t]
      ~derive:Dashboard_state.memory_view
      ~view:Memory_pane.view
  in
  let participants =
    pane_node
      ~equal:[%equal: Dashboard_state.Participants_view.t]
      ~derive:Dashboard_state.participants_view
      ~view:Participants_pane.view
  in
  let depth = Depth_pane.component ~state graph in
  let dispatch_stop =
    Rpc_effect.Rpc.dispatcher
      Jsip_dashboard_protocol.Scenario_control.stop_scenario_rpc
      graph
  in
  let banner =
    let%arr status and reset and dispatch_stop in
    (* Reset stops the running scenario before clearing the sample window.
       With the exchange child dead no fresh samples arrive to refill the
       panes, so they clear and stay empty. Stop first, then clear, so the
       clear lands once the feed has already gone quiet. *)
    let reset =
      let%bind.Effect (_ : unit Or_error.t Or_error.t) = dispatch_stop () in
      reset
    in
    Connection_banner.view ~reset status
  in
  let controls = Scenario_controls.component graph in
  let%arr banner
  and controls
  and submit_latency
  and cancel_latency
  and loop
  and occupancy
  and memory
  and participants
  and depth in
  {%html|
    <div %{Styles.page}>
      %{banner}
      %{controls}
      <div %{Styles.grid}>
        %{submit_latency}
        %{cancel_latency}
        %{loop}
        %{occupancy}
        %{memory}
        %{participants}
        %{depth}
      </div>
    </div>
  |}
;;
