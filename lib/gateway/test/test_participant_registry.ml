(** Tests for {!Jsip_gateway.Participant_id.Registry}: ids are dense and
    assigned in first-login order, interning is idempotent (so a participant
    keeps its id across reconnects), lookups resolve in both directions, and
    the registry keeps working as it grows. *)

open! Core
open Jsip_types
open Jsip_test_harness
open Jsip_gateway

let%expect_test "ids are dense, in first-sight order, and stable on \
                 re-intern"
  =
  let registry = Participant_id.Registry.create () in
  let intern participant =
    let id = Participant_id.Registry.intern registry participant in
    print_s [%message (participant : Participant.t) (id : Participant_id.t)]
  in
  intern Harness.alice;
  intern Harness.bob;
  (* Re-interning is what a reconnect does: same name, same id. *)
  intern Harness.alice;
  [%expect
    {|
    ((participant Alice) (id 0))
    ((participant Bob) (id 1))
    ((participant Alice) (id 0))
    |}]
;;

let%expect_test "find and name resolve both directions; unknown name is None"
  =
  let registry = Participant_id.Registry.create () in
  let id = Participant_id.Registry.intern registry Harness.alice in
  let round_trip = Participant_id.Registry.name registry id in
  let known = Participant_id.Registry.find registry Harness.alice in
  let unknown = Participant_id.Registry.find registry Harness.bob in
  print_s
    [%message
      (round_trip : Participant.t)
        (known : Participant_id.t option)
        (unknown : Participant_id.t option)];
  [%expect {| ((round_trip Alice) (known (0)) (unknown ())) |}]
;;

let%expect_test "registry grows past its initial capacity" =
  let registry = Participant_id.Registry.create () in
  let participants =
    List.init 100 ~f:(fun i -> Participant.of_string [%string "P%{i#Int}"])
  in
  List.iter participants ~f:(fun participant ->
    ignore
      (Participant_id.Registry.intern registry participant
       : Participant_id.t));
  let all_round_trip =
    List.for_all participants ~f:(fun participant ->
      let id = Participant_id.Registry.intern registry participant in
      Participant.equal
        (Participant_id.Registry.name registry id)
        participant)
  in
  print_s [%message (all_round_trip : bool)];
  [%expect {| (all_round_trip true) |}]
;;
