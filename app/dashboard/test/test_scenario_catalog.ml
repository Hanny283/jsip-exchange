open! Core
module Scenario_catalog = Jsip_dashboard_server.Scenario_catalog
module Scenario_info = Jsip_dashboard_protocol.Scenario_control.Scenario_info

(* Drift guard between the authored dashboard catalog and the scenario
   registry the [scenario_runner] actually knows how to launch.

   [Scenario_catalog.all] is hand-written pedagogical content (a blurb plus
   predicted pane behaviors per scenario); [Jsip_scenarios.all] is the list
   of runnable scenarios. If someone adds a scenario to the runner without a
   catalog entry, the dashboard would offer no button for it; if someone adds
   a catalog entry whose [name] no scenario answers to, its Run button would
   spawn a child that immediately fails. Either way the two name sets
   diverge, and this test fails and names exactly which side is missing what. *)

let catalog_names =
  List.map Scenario_catalog.all ~f:(fun (info : Scenario_info.t) ->
    info.name)
  |> String.Set.of_list
;;

let registry_names =
  List.map
    Jsip_scenarios.all
    ~f:(fun (module S : Jsip_scenarios.Scenario.S) -> S.name)
  |> String.Set.of_list
;;

let%expect_test "catalog names match the scenario registry" =
  let only_in_catalog = Set.diff catalog_names registry_names in
  let only_in_registry = Set.diff registry_names catalog_names in
  print_s
    [%message
      (only_in_catalog : String.Set.t) (only_in_registry : String.Set.t)];
  [%expect {| ((only_in_catalog ()) (only_in_registry ())) |}]
;;
