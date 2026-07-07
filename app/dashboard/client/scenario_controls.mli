(** The scenario control bar: the band under the {!Connection_banner} that
    launches scenarios and, for the running one, shows the authored
    prediction of how each pane should look.

    It owns three RPCs against the dashboard's own server (see
    {!Jsip_dashboard_protocol.Scenario_control}):

    - polls [scenario_status_rpc] once a second for what is live and the last
      launch/exit error;
    - fetches [list_scenarios_rpc] every 15s (the catalog is static), so the
      bar renders a muted "loading…" state until the first list arrives;
    - dispatches [run_scenario_rpc] / [stop_scenario_rpc] from the Run and
      Stop buttons.

    Scenarios are grouped by {!Scenario_control.Category} with the
    pathological ones first and emphasized — those are the failure modes the
    dashboard exists to expose. Each card is a Run button (which also opens
    the card) and a caret that opens it without launching; the open panel
    lists the blurb and the per-pane predictions the operator compares
    against the live panes. The running scenario's card is treated as open so
    its predictions stay up.

    Like the rest of the client this never raises: a failing poll surfaces as
    the connection banner going red, and a failed launch as the error line
    under the header. *)

open! Core
open Bonsai_web

(** [component graph] builds the control bar. It takes no inputs — it drives
    its own polling and dispatch — so the app just places it between the
    {!Connection_banner} and the pane grid. *)
val component : local_ Bonsai.graph -> Vdom.Node.t Bonsai.t
