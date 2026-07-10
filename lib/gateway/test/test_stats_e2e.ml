(** End-to-end tests for the exchange-stats RPC.

    These spin up a real server with a huge stats interval — so the only
    unforced snapshot is the immediate startup tick, which fires before any
    client connects — drive traffic through logged-in RPC clients, then force
    snapshots via {!Exchange_server.For_testing.publish_stats_snapshot} and
    check a hand-rolled projection of each snapshot. The projection prints
    only deterministic facts (sequence numbers, counts, depths, booleans),
    never wall-clock times, latency buckets, or raw GC numbers. *)

open! Core
open! Async
open Jsip_types
open Jsip_gateway
open Jsip_test_harness
open E2e_helpers

(* Effectively "snapshots never fire on their own": only the immediate
   startup tick (seq 1, before any client connects) is unforced, so the seq
   of every forced snapshot is pinned. *)
let stats_interval_never = Time_ns.Span.of_day 1.

(* Read the next snapshot off a stats feed, failing the test if the server
   closed it. *)
let read_snapshot_exn (stats_feed : Exchange_stats.t Pipe.Reader.t) =
  match%map Pipe.read stats_feed with
  | `Ok snapshot -> snapshot
  | `Eof -> failwith "stats feed closed unexpectedly"
;;

(* A deterministic projection of a snapshot. The raw sexp would leak the
   sampling time, latency buckets, and GC numbers, none of which are stable
   across runs. *)
let print_snapshot (snapshot : Exchange_stats.t) =
  print_endline [%string "seq=%{snapshot.seq#Int}"];
  List.iter snapshot.participants ~f:(fun (participant, stats) ->
    let { Exchange_stats.Participant_stats.orders_submitted
        ; cancels_submitted
        ; resting_orders
        }
      =
      stats
    in
    print_endline
      [%string
        "participant %{participant#Participant}: \
         orders_submitted=%{orders_submitted#Int} \
         cancels_submitted=%{cancels_submitted#Int} \
         resting_orders=%{resting_orders#Int}"]);
  let side_to_string { Exchange_stats.Side_depth.total_size; order_count } =
    [%string "size=%{total_size#Size} orders=%{order_count#Int}"]
  in
  List.iter snapshot.books ~f:(fun (symbol, depth) ->
    let { Exchange_stats.Book_depth.bbo; bids; asks } = depth in
    print_endline
      [%string
        "book %{symbol#Symbol_id}: bbo=[%{Bbo.to_string bbo}] \
         bids=[%{side_to_string bids}] asks=[%{side_to_string asks}]"]);
  let { Exchange_stats.Pipe_occupancy.request_queue
      ; audit_subscribers
      ; market_data_subscribers
      ; sessions
      ; stats_subscribers
      }
    =
    snapshot.pipes
  in
  let audit_count = List.length audit_subscribers in
  let market_data_symbol_count = List.length market_data_subscribers in
  let session_count = List.length sessions in
  let stats_count = List.length stats_subscribers in
  print_endline
    [%string
      "pipes: request_queue=%{request_queue#Int} \
       audit_subscribers=%{audit_count#Int} \
       market_data_symbols=%{market_data_symbol_count#Int} \
       sessions=%{session_count#Int} stats_subscribers=%{stats_count#Int}"];
  let submit_count = Span_histogram.total_count snapshot.latencies.submit in
  let cancel_count = Span_histogram.total_count snapshot.latencies.cancel in
  print_endline
    [%string
      "latencies: submits=%{submit_count#Int} cancels=%{cancel_count#Int}"];
  print_endline [%string "loop: iterations=%{snapshot.loop.iterations#Int}"];
  let heap_is_live = snapshot.gc.live_words > 0 in
  print_endline [%string "gc: live_words > 0 = %{heap_is_live#Bool}"]
;;

let%expect_test "e2e: stats snapshots reflect traffic, books, and pipes" =
  with_server
    ~symbols:[ Symbol.of_string "AAPL" ]
    ~stats_interval:stats_interval_never
    (fun ~server ~port ->
      let%bind alice = connect_as ~port Harness.alice in
      let%bind bob = connect_as ~port Harness.bob in
      (* The stats RPC needs no login, but [connect_as] is the easiest way to
         get a [client]; the observer's session shows up as a third row in
         the pipe occupancy. *)
      let%bind observer = connect_as ~port (Participant.of_string "Stats") in
      let%bind stats = subscribe_stats observer in
      (* Bob rests two sells with pinned client_order_ids: the first will be
         crossed by Alice, the second cancelled. The session-feed prints
         between steps guarantee the matching loop processed each command. *)
      let sell_to_cross : Order.Request.t =
        { symbol = Harness.aapl
        ; side = Sell
        ; price = Price.of_int_cents 15000
        ; size = Size.of_int 100
        ; time_in_force = Day
        ; client_order_id = Client_order_id.of_string "101"
        }
      in
      let%bind () = rpc_submit bob sell_to_cross in
      [%expect {| [Bob] ACCEPTED id=1 0 SELL 100@$150.00 DAY |}];
      let sell_to_cancel : Order.Request.t =
        { sell_to_cross with
          price = Price.of_int_cents 15100
        ; size = Size.of_int 50
        ; client_order_id = Client_order_id.of_string "102"
        }
      in
      let%bind () = rpc_submit bob sell_to_cancel in
      [%expect {| [Bob] ACCEPTED id=2 0 SELL 50@$151.00 DAY |}];
      (* Alice's buy crosses Bob's first sell and rests its remainder, so
         there is book depth left to report at sampling time. *)
      let crossing_buy : Order.Request.t =
        { symbol = Harness.aapl
        ; side = Buy
        ; price = Price.of_int_cents 15000
        ; size = Size.of_int 150
        ; time_in_force = Day
        ; client_order_id = Client_order_id.of_string "103"
        }
      in
      let%bind () = rpc_submit alice crossing_buy in
      [%expect
        {|
         [Alice] ACCEPTED id=3 0 BUY 150@$150.00 DAY
         [Alice] FILL fill_id=1 0 $150.00 x100 aggressor=3(Alice) client_id=103 BUY resting=1(Bob) client_id=101
         [Bob] FILL fill_id=1 0 $150.00 x100 aggressor=3(Alice) client_id=103 BUY resting=1(Bob) client_id=101
         |}];
      let%bind cancel_result =
        Rpc.Rpc.dispatch_exn
          Rpc_protocol.cancel_order_rpc
          (connection bob)
          (Client_order_id.of_string "102")
      in
      ok_exn cancel_result;
      [%expect
        {| [Bob] CANCELLED client_id=102 id=2 0 remaining=50 reason=PARTICIPANT_REQUESTED |}];
      (* The startup tick consumed seq 1 before any client connected, so the
         first forced snapshot is seq 2, and it covers all four commands
         above. *)
      let%bind () = Scheduler.yield_until_no_jobs_remain () in
      Exchange_server.For_testing.publish_stats_snapshot server;
      let%bind snapshot = read_snapshot_exn stats in
      print_snapshot snapshot;
      [%expect
        {|
        seq=2
        participant Alice: orders_submitted=1 cancels_submitted=0 resting_orders=1
        participant Bob: orders_submitted=2 cancels_submitted=1 resting_orders=0
        book 0: bbo=[$150.00 x50 / -] bids=[size=50 orders=1] asks=[size=0 orders=0]
        pipes: request_queue=0 audit_subscribers=0 market_data_symbols=0 sessions=3 stats_subscribers=1
        latencies: submits=3 cancels=1
        loop: iterations=4
        gc: live_words > 0 = true
        |}];
      (* A second forced snapshot with no traffic in between: interval
         counters reset to zero, point-in-time facts (resting orders, book
         depth, pipe counts) are unchanged, and seq bumps by one. Bob
         disappears from the participants: he has no interval activity and
         nothing resting. *)
      Exchange_server.For_testing.publish_stats_snapshot server;
      let%bind snapshot = read_snapshot_exn stats in
      print_snapshot snapshot;
      [%expect
        {|
        seq=3
        participant Alice: orders_submitted=0 cancels_submitted=0 resting_orders=1
        book 0: bbo=[$150.00 x50 / -] bids=[size=50 orders=1] asks=[size=0 orders=0]
        pipes: request_queue=0 audit_subscribers=0 market_data_symbols=0 sessions=3 stats_subscribers=1
        latencies: submits=0 cancels=0
        loop: iterations=0
        gc: live_words > 0 = true
        |}];
      return ())
;;

let%expect_test "e2e: every stats subscriber gets each snapshot; a closed \
                 one is dropped"
  =
  with_server
    ~symbols:[ Symbol.of_string "AAPL" ]
    ~stats_interval:stats_interval_never
    (fun ~server ~port ->
      let%bind observer = connect_as ~port (Participant.of_string "Stats") in
      let%bind stats_a = subscribe_stats observer in
      let%bind stats_b = subscribe_stats observer in
      let stats_pipe_count (snapshot : Exchange_stats.t) =
        List.length snapshot.pipes.stats_subscribers
      in
      Exchange_server.For_testing.publish_stats_snapshot server;
      let%bind snapshot_a = read_snapshot_exn stats_a in
      let%bind snapshot_b = read_snapshot_exn stats_b in
      print_s
        [%message
          "both subscribers saw the tick"
            ~seq_a:(snapshot_a.seq : int)
            ~seq_b:(snapshot_b.seq : int)
            ~stats_pipes:(stats_pipe_count snapshot_a : int)];
      [%expect
        {| ("both subscribers saw the tick" (seq_a 2) (seq_b 2) (stats_pipes 2)) |}];
      (* Closing one reader unregisters it from the publisher's bag: the next
         tick still succeeds, and it reports one remaining stats pipe. *)
      Pipe.close_read stats_a;
      (* The close reaches the server as an abort message on the observer's
         connection, so a yield alone doesn't cover it. RPC messages on one
         connection are processed in order: once a round-trip on the same
         connection completes, the server has seen the abort, and the final
         yield runs its local unsubscribe job. *)
      let%bind () = Scheduler.yield_until_no_jobs_remain () in
      let%bind (_ : Book.t option) = rpc_book observer Harness.aapl in
      let%bind () = Scheduler.yield_until_no_jobs_remain () in
      Exchange_server.For_testing.publish_stats_snapshot server;
      let%bind snapshot_b = read_snapshot_exn stats_b in
      print_s
        [%message
          "after closing one reader"
            ~seq_b:(snapshot_b.seq : int)
            ~stats_pipes:(stats_pipe_count snapshot_b : int)];
      [%expect {| ("after closing one reader" (seq_b 3) (stats_pipes 1)) |}];
      return ())
;;
