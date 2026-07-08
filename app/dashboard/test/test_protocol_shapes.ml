open! Core
open Async_rpc_kernel
open Jsip_dashboard_protocol

(* Wire-shape test for the dashboard's polling RPC, in the same style as
   [lib/gateway/test/test_rpc_shapes.ml].

   The test pins the RPC's *wire contract*: its name, its version, and a
   digest of the [bin_io] shape of each type it puts on the wire — the query
   it receives and the response it sends.

   A bin-shape digest is a stable fingerprint of how a value is serialized.
   It changes whenever the serialized layout of a type changes: adding a
   field to [Recent_samples.Query.t], changing [Exchange_stats.t] (which
   [Response.t] embeds), or pointing the RPC at a different type all move the
   digest. The dashboard server and the browser client can only talk over
   this RPC if they agree on its name, version, and these digests, so this
   test is the precise statement of "what's on the wire."

   If a digest changes, read the diff, convince yourself the change was
   intended (and that server and client will be rebuilt together), then
   accept it with [dune promote]. *)

let%expect_test "dashboard-recent-samples RPC" =
  print_s [%sexp (Rpc.Rpc.shapes Recent_samples.rpc : Rpc_shapes.t)];
  [%expect
    {|
    (Rpc (query 2c01d06c34b0a95841c2f2ddd8090f5b)
     (response abd2fa386e1dad22535ed01cdcd82b03))
    |}]
;;

let%expect_test "dashboard-list-scenarios RPC" =
  print_s
    [%sexp
      (Rpc.Rpc.shapes Scenario_control.list_scenarios_rpc : Rpc_shapes.t)];
  [%expect
    {|
    (Rpc (query 86ba5df747eec837f0b391dd49f33f9e)
     (response 197559ff8bb56e920ce5ceead901e885))
    |}]
;;

let%expect_test "dashboard-run-scenario RPC" =
  print_s
    [%sexp (Rpc.Rpc.shapes Scenario_control.run_scenario_rpc : Rpc_shapes.t)];
  [%expect
    {|
    (Rpc (query d8c64f6d09943ee95f13b675a0c9792e)
     (response 27f76252e5181aab209cd62aa6e42268))
    |}]
;;

let%expect_test "dashboard-stop-scenario RPC" =
  print_s
    [%sexp
      (Rpc.Rpc.shapes Scenario_control.stop_scenario_rpc : Rpc_shapes.t)];
  [%expect
    {|
    (Rpc (query 86ba5df747eec837f0b391dd49f33f9e)
     (response 27f76252e5181aab209cd62aa6e42268))
    |}]
;;

let%expect_test "dashboard-scenario-status RPC" =
  print_s
    [%sexp
      (Rpc.Rpc.shapes Scenario_control.scenario_status_rpc : Rpc_shapes.t)];
  [%expect
    {|
    (Rpc (query 86ba5df747eec837f0b391dd49f33f9e)
     (response 3aebd89e3c0b0a197d220e56b6bc880f))
    |}]
;;
