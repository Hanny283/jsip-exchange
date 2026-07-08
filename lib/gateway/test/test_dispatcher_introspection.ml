(** Tests for {!Jsip_gateway.Dispatcher}'s introspection accessors.

    These build a dispatcher directly (no server, no RPC), attach one audit
    subscriber, one market-data subscriber covering two symbols, and one
    session, then dispatch {!Jsip_test_harness.Harness.sample_events} without
    draining any reader. The pipe lengths reported by the accessors must
    reflect exactly the undrained events each subscriber was routed. *)

open! Core
open! Async
open Jsip_types
open Jsip_gateway
open Jsip_test_harness

let print_pipe_lengths dispatcher =
  print_s
    [%message
      ""
        ~audit:(Dispatcher.audit_pipe_lengths dispatcher : int list)
        ~market_data:
          (Dispatcher.market_data_pipe_lengths dispatcher
           : (Symbol.t * int list) list)
        ~sessions:
          (Dispatcher.session_pipe_lengths dispatcher
           : (Participant.t * int) list)]
;;

let%expect_test "pipe lengths reflect undrained dispatched events" =
  let dispatcher = Dispatcher.create () in
  (* One audit subscriber; one market-data subscriber whose single pipe
     covers both AAPL and TSLA; one logged-in session for Alice. We hold the
     readers but never drain them, so every dispatched event stays buffered
     and is visible to the accessors. *)
  let (_ : Exchange_event.t Pipe.Reader.t) =
    Dispatcher.subscribe_audit dispatcher
  in
  let (_ : Exchange_event.t Pipe.Reader.t) =
    Dispatcher.subscribe_market_data
      dispatcher
      [ Harness.aapl; Harness.tsla ]
  in
  let%bind () = Dispatcher.set_up_session dispatcher Harness.alice in
  (* Before any dispatch, every pipe is registered but empty. *)
  print_pipe_lengths dispatcher;
  [%expect
    {| ((audit (0)) (market_data ((AAPL (0)) (TSLA (0)))) (sessions ((Alice 0)))) |}];
  Dispatcher.dispatch dispatcher Harness.sample_events;
  (* [sample_events] is one event per constructor, all on AAPL:
     - audit receives all 6;
     - the market-data subscriber receives [Best_bid_offer_update] and
       [Trade_report] (both AAPL) exactly once each — and, because it shares
       one pipe across its two symbols, it shows up under both AAPL and TSLA
       with the same total length of 2;
     - Alice's session receives [Order_accept], [Fill] (she is the
       aggressor), [Order_cancel], and [Order_reject] = 4. The [Fill]'s
       resting party is Bob, who has no session, so that copy is dropped. *)
  print_pipe_lengths dispatcher;
  [%expect
    {| ((audit (6)) (market_data ((AAPL (2)) (TSLA (2)))) (sessions ((Alice 4)))) |}];
  return ()
;;

let%expect_test "a saturated firehose is bounded: excess events are dropped" =
  let dispatcher = Dispatcher.create () in
  let (_ : Exchange_event.t Pipe.Reader.t) =
    Dispatcher.subscribe_audit dispatcher
  in
  let (_ : Exchange_event.t Pipe.Reader.t) =
    Dispatcher.subscribe_market_data dispatcher [ Harness.aapl ]
  in
  (* A subscriber that never drains its reader stands in for one that has
     fallen hopelessly behind. Flooding it with far more than the backlog cap
     of 1024 leaves both the market-data and audit pipes pinned at the cap
     rather than buffering all 3000 events: the memory a slow consumer can pin
     is bounded, and the backlog is exactly what the occupancy pane reports. *)
  let trade : Exchange_event.t =
    Trade_report
      { symbol = Harness.aapl
      ; price = Price.of_int_cents 15000
      ; size = Size.of_int 1
      }
  in
  Dispatcher.dispatch dispatcher (List.init 3000 ~f:(fun _ -> trade));
  print_pipe_lengths dispatcher;
  [%expect
    {| ((audit (1024)) (market_data ((AAPL (1024)))) (sessions ())) |}];
  return ()
;;
