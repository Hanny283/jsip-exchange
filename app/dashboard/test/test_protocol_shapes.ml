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
     (response 4c5a92191dcc19fff95025300ffdb597))
    |}]
;;
