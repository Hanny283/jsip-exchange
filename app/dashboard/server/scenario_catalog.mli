(** The authored catalog of launchable scenarios, server-side.

    Each entry pairs a scenario's CLI name with a human blurb and a list of
    predicted pane behaviors — the reference card the dashboard shows next to
    the live panes so the user can compare "what should happen" against "what
    is happening". The catalog is pure data
    ({!Jsip_dashboard_protocol.Scenario_control.Scenario_info.t}) so it can
    cross the websocket to the browser client, which never links the scenario
    or exchange libraries.

    {!all} is kept in one-to-one correspondence with {!Jsip_scenarios.all}: a
    drift test in [app/dashboard/test/test_scenario_catalog.ml] asserts the
    two sets of names are equal, so adding a scenario to the runner without a
    catalog entry (or vice versa) fails the build.

    {!is_known} is the allowlist the {!Scenario_manager} checks before
    spawning a child process, so an out-of-catalog name can never reach the
    process spawner. *)

open! Core
module Scenario_control = Jsip_dashboard_protocol.Scenario_control

(** Every launchable scenario, in the same order as {!Jsip_scenarios.all}. *)
val all : Scenario_control.Scenario_info.t list

(** [is_known name] is [true] iff [name] is the {!Scenario_info.name} of some
    entry in {!all}. The scenario manager uses it to validate a run request
    before spawning. *)
val is_known : string -> bool
