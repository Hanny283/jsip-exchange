open! Core
open! Async
open Jsip_types
open Jsip_order_book

type t =
  { collector : Stats_collector.t
  ; dispatcher : Dispatcher.t
  ; engine : Matching_engine.t
  ; symbols : Symbol.t list
  ; request_queue_length : unit -> int
  ; subscribers : Exchange_stats.t Pipe.Writer.t Bag.t
  ; mutable seq : int
  }

let create ~collector ~dispatcher ~engine ~symbols ~request_queue_length =
  { collector
  ; dispatcher
  ; engine
  ; (* Sorted once here so the per-tick book scan emits [books] rows already
       in the order the snapshot type promises. *)
    symbols = List.sort symbols ~compare:Symbol.compare
  ; request_queue_length
  ; subscribers = Bag.create ()
  ; seq = 0
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
      Dispatcher.market_data_pipe_lengths t.dispatcher
  ; sessions = Dispatcher.session_pipe_lengths t.dispatcher
  ; stats_subscribers = Bag.to_list t.subscribers |> List.map ~f:Pipe.length
  }
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
  List.filter_map t.symbols ~f:(fun symbol ->
    match Matching_engine.book t.engine symbol with
    | None -> None
    | Some book ->
      let depth : Exchange_stats.Book_depth.t =
        { bbo = Order_book.best_bid_offer book
        ; bids = side_depth book Buy ~resting_counts
        ; asks = side_depth book Sell ~resting_counts
        }
      in
      Some (symbol, depth))
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
   participant. *)
let participant_rows ~per_participant ~resting_counts =
  let submitted = Participant.Map.of_alist_exn per_participant in
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
  let pipes = pipe_occupancy t in
  let resting_counts = Participant.Table.create () in
  let books = book_depths t ~resting_counts in
  let participants = participant_rows ~per_participant ~resting_counts in
  let snapshot : Exchange_stats.t =
    { seq = t.seq
    ; sampled_at
    ; gc
    ; latencies
    ; pipes
    ; participants
    ; books
    ; loop
    }
  in
  Bag.iter t.subscribers ~f:(fun writer ->
    Pipe.write_without_pushback_if_open writer snapshot)
;;

let start t ~interval ~stop =
  Clock_ns.every ~stop interval (fun () -> tick t)
;;
