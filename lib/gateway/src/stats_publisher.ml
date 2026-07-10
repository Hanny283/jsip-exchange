open! Core
open! Async
open Jsip_types
open Jsip_order_book

type t =
  { collector : Stats_collector.t
  ; dispatcher : Dispatcher.t
  ; registry : Participant_id.Registry.t
      (* The collector's flushed rows are keyed by [Participant_id.t]; the
         snapshot is a wire type and speaks names, so this edge resolves ids
         back through the registry. *)
  ; engine : Matching_engine.t
  ; symbols : Symbol_id.t list
      (* The traded ids [0 .. num_symbols - 1], in id order — which is also
         the order the snapshot's per-symbol rows come out in. *)
  ; request_queue_length : unit -> int
  ; fundamental : Symbol_id.t -> Price.t option
      (* The scenario oracle's fair price for a symbol, or [None] when there
         is no oracle (standalone server) or the symbol is unknown to it. A
         closure because the oracle lives in [jsip_scenario_runner], which
         the gateway must not depend on. *)
  ; subscribers : Exchange_stats.t Pipe.Writer.t Bag.t
  ; mutable seq : int
  ; mutable peak_pipes : Exchange_stats.Pipe_occupancy.t option
  (* High-water mark of pipe occupancy since the last tick, accumulated by a
     fast sub-tick sampler. Backpressure is bursty, so a single reading once
     per interval misses spikes that fill and drain between ticks. *)
  }

let create
  ~collector
  ~dispatcher
  ~registry
  ~engine
  ~num_symbols
  ~request_queue_length
  ~fundamental
  =
  { collector
  ; dispatcher
  ; registry
  ; engine
  ; symbols = List.init num_symbols ~f:Symbol_id.of_int
  ; request_queue_length
  ; fundamental
  ; subscribers = Bag.create ()
  ; seq = 0
  ; peak_pipes = None
  }
;;

(* Same register/remove-on-close pattern as [Dispatcher.subscribe_audit]: the
   writer lives in the bag until the subscriber closes its reader. *)
let subscribe t =
  let reader, writer = Pipe.create () in
  let elt = Bag.add t.subscribers writer in
  don't_wait_for
    (let%map () = Pipe.closed writer in
     Bag.remove t.subscribers elt);
  reader
;;

let pipe_occupancy t : Exchange_stats.Pipe_occupancy.t =
  { request_queue = t.request_queue_length ()
  ; audit_subscribers = Dispatcher.audit_pipe_lengths t.dispatcher
  ; market_data_subscribers =
      (* Already id-keyed and id-ordered straight off the dispatcher. *)
      Dispatcher.market_data_pipe_lengths t.dispatcher
  ; sessions = Dispatcher.session_pipe_lengths t.dispatcher
  ; stats_subscribers = Bag.to_list t.subscribers |> List.map ~f:Pipe.length
  }
;;

(* Element-wise max of two per-pipe length lists. The subscriber set is
   effectively stable across a tick's sub-samples; if it did change, keep the
   tail of whichever list is longer rather than dropping a pipe. *)
let rec max_lengths a b =
  match a, b with
  | [], rest | rest, [] -> rest
  | x :: xs, y :: ys -> Int.max x y :: max_lengths xs ys
;;

(* Merge two occupancy readings into their per-pipe maxima. Keyed lists
   (per-symbol market data, per-participant sessions) are unioned by key. *)
let merge_pipe_max
  (a : Exchange_stats.Pipe_occupancy.t)
  (b : Exchange_stats.Pipe_occupancy.t)
  : Exchange_stats.Pipe_occupancy.t
  =
  let market_data_subscribers =
    Map.merge
      (Symbol_id.Map.of_alist_exn a.market_data_subscribers)
      (Symbol_id.Map.of_alist_exn b.market_data_subscribers)
      ~f:(fun ~key:_ -> function `Left lens | `Right lens -> Some lens
      | `Both (x, y) -> Some (max_lengths x y))
    |> Map.to_alist
  in
  let sessions =
    Map.merge
      (Participant.Map.of_alist_exn a.sessions)
      (Participant.Map.of_alist_exn b.sessions)
      ~f:(fun ~key:_ -> function `Left len | `Right len -> Some len
      | `Both (x, y) -> Some (Int.max x y))
    |> Map.to_alist
  in
  { request_queue = Int.max a.request_queue b.request_queue
  ; audit_subscribers = max_lengths a.audit_subscribers b.audit_subscribers
  ; market_data_subscribers
  ; sessions
  ; stats_subscribers = max_lengths a.stats_subscribers b.stats_subscribers
  }
;;

(* Fold the current instant into the running high-water mark. Runs on the
   fast sub-tick clock so a transient spike is recorded even if the next full
   tick lands after it has drained. *)
let sample_peak t =
  let current = pipe_occupancy t in
  t.peak_pipes
  <- Some
       (match t.peak_pipes with
        | None -> current
        | Some peak -> merge_pipe_max peak current)
;;

(* Scan one side of a book, accumulating depth and bumping each resting
   order's participant in [resting_counts]. A single [iter_orders] pass — no
   intermediate list. *)
let side_depth book side ~resting_counts : Exchange_stats.Side_depth.t =
  let total_size = ref Size.zero in
  let order_count = ref 0 in
  Order_book.iter_orders book side ~f:(fun order ->
    total_size := Size.( + ) !total_size (Order.remaining_size order);
    incr order_count;
    Hashtbl.incr resting_counts (Order.participant order));
  { total_size = !total_size; order_count = !order_count }
;;

let book_depths t ~resting_counts =
  List.filter_map t.symbols ~f:(fun id ->
    match Matching_engine.book t.engine id with
    | None -> None
    | Some book ->
      let depth : Exchange_stats.Book_depth.t =
        { bbo = Order_book.best_bid_offer book
        ; bids = side_depth book Buy ~resting_counts
        ; asks = side_depth book Sell ~resting_counts
        }
      in
      Some (id, depth))
;;

(* The oracle's fair price for each symbol whose fundamental is known, in the
   same id order as [books]. Symbols with no oracle price (all of them on a
   standalone server) are dropped, so the list is empty there. *)
let fundamentals t =
  List.filter_map t.symbols ~f:(fun id ->
    Option.map (t.fundamental id) ~f:(fun price -> id, price))
;;

let no_commands_submitted : Stats_collector.Flushed.Counts.t =
  { orders_submitted = 0; cancels_submitted = 0 }
;;

let participant_stats
  ({ orders_submitted; cancels_submitted } :
    Stats_collector.Flushed.Counts.t)
  ~resting_orders
  : Exchange_stats.Participant_stats.t
  =
  { orders_submitted; cancels_submitted; resting_orders }
;;

(* Join the interval's per-participant command counts with the point-in-time
   resting-order counts from the book scan: union of keys, with zeros for
   whichever side is missing. [Map.to_alist] keeps the rows sorted by
   participant. The flushed counts arrive keyed by id and are resolved to
   names here — this is the edge where the snapshot (a wire type) is built,
   so it is where ids stop. *)
let participant_rows t ~per_participant ~resting_counts =
  let submitted =
    Participant.Map.of_alist_exn
      (List.map per_participant ~f:(fun (id, counts) ->
         Participant_id.Registry.name t.registry id, counts))
  in
  let resting =
    Participant.Map.of_alist_exn (Hashtbl.to_alist resting_counts)
  in
  Map.merge submitted resting ~f:(fun ~key:_ -> function
    | `Left counts -> Some (participant_stats counts ~resting_orders:0)
    | `Right resting_orders ->
      Some (participant_stats no_commands_submitted ~resting_orders)
    | `Both (counts, resting_orders) ->
      Some (participant_stats counts ~resting_orders))
  |> Map.to_alist
;;

let tick t =
  t.seq <- t.seq + 1;
  let sampled_at = Time_ns.now () in
  (* [Gc.stat] walks the whole major heap; we pay that cost exactly once per
     tick. *)
  let gc = Exchange_stats.Gc_stats.of_stat (Gc.stat ()) in
  let { Stats_collector.Flushed.latencies; per_participant; loop } =
    Stats_collector.flush t.collector
  in
  (* Report the high-water mark accumulated since the previous tick (folding
     in this instant), then reset it, so the pane shows the worst
     backpressure in each interval rather than whatever a single instant
     happened to catch. *)
  let pipes =
    let current = pipe_occupancy t in
    match t.peak_pipes with
    | None -> current
    | Some peak -> merge_pipe_max peak current
  in
  t.peak_pipes <- None;
  let resting_counts = Participant.Table.create () in
  let books = book_depths t ~resting_counts in
  let participants = participant_rows t ~per_participant ~resting_counts in
  let snapshot : Exchange_stats.t =
    { seq = t.seq
    ; sampled_at
    ; gc
    ; latencies
    ; pipes
    ; participants
    ; books
    ; fundamentals = fundamentals t
    ; loop
    }
  in
  Bag.iter t.subscribers ~f:(fun writer ->
    Pipe.write_without_pushback_if_open writer snapshot)
;;

(* How often the high-water-mark sampler peeks at pipe occupancy between full
   ticks. Fast enough to catch bursty backpressure, cheap enough to ignore (a
   handful of [Pipe.length] reads). *)
let peek_interval = Time_ns.Span.of_int_ms 25

let start t ~interval ~stop =
  Clock_ns.every ~stop peek_interval (fun () -> sample_peak t);
  Clock_ns.every ~stop interval (fun () -> tick t)
;;
