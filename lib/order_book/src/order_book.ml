open! Core
open Jsip_types

type t =
  { symbol : Symbol_id.t
  ; mutable bids : Order.t Queue.t Price.Map.t
  ; mutable asks : Order.t Queue.t Price.Map.t
  ; mutable identifiers : Order.t Order_id.Map.t
  ; mutable best_bid_level : (Price.t * Order.t Queue.t) option
      (* Cache of the best (price, level queue) per side. Every incoming
         order consults the best price at least once, so reading it off the
         map's extreme key made the hottest read in the engine O(log levels).
         The cache makes it O(1); the tree is only consulted again when the
         best level empties (see [remove']). The queue is the SAME object the
         map holds — levels mutate in place — so the cache never goes stale
         from enqueues/fills at the best price. The full cache/map coherence
         invariant is checked by [For_testing.invariant], which
         [test_order_book_invariants.ml] hammers with randomized workloads:
         any mutation path that desynchronizes the cache fails loudly there
         before it can misprice a fill here. *)
  ; mutable best_ask_level : (Price.t * Order.t Queue.t) option
  }
[@@deriving sexp_of]

let create symbol =
  { symbol
  ; bids = Price.Map.empty
  ; asks = Price.Map.empty
  ; identifiers = Order_id.Map.empty
  ; best_bid_level = None
  ; best_ask_level = None
  }
;;

let symbol t = t.symbol

let side_levels t side =
  match (side : Side.t) with Buy -> t.bids | Sell -> t.asks
;;

let set_side_levels t side orders =
  match (side : Side.t) with
  | Buy -> t.bids <- orders
  | Sell -> t.asks <- orders
;;

let set_identifiers t identifiers = t.identifiers <- identifiers

let best_level_entry t side =
  match (side : Side.t) with
  | Buy -> t.best_bid_level
  | Sell -> t.best_ask_level
;;

let set_best_level_entry t side entry =
  match (side : Side.t) with
  | Buy -> t.best_bid_level <- entry
  | Sell -> t.best_ask_level <- entry
;;

(* Re-read the best level off the map's extreme key: highest bid, lowest ask.
   O(log levels) — only paid when the cached best level empties. *)
let recompute_best_level t side =
  let entry =
    match (side : Side.t) with
    | Buy -> Map.max_elt t.bids
    | Sell -> Map.min_elt t.asks
  in
  set_best_level_entry t side entry
;;

let add t order =
  let order_id = Order.order_id order in
  Map.set t.identifiers ~key:order_id ~data:order |> set_identifiers t;
  let side = Order.side order in
  let price = Order.price order in
  let levels = side_levels t side in
  let queue =
    match Map.find levels price with
    | Some queue ->
      Queue.enqueue queue order;
      queue
    | None ->
      let queue = Queue.create () in
      Queue.enqueue queue order;
      Map.add_exn levels ~key:price ~data:queue |> set_side_levels t side;
      queue
  in
  (* Maintain the cache: a new best takes over; an enqueue AT the best price
     needs nothing (the cached queue is the same object the map holds). *)
  match best_level_entry t side with
  | None -> set_best_level_entry t side (Some (price, queue))
  | Some (best_price, _) ->
    if Price.is_more_aggressive side ~price ~than:best_price
    then set_best_level_entry t side (Some (price, queue))
;;

let remove' t order_id =
  let order = Map.find t.identifiers order_id in
  match order with
  | None -> None
  | Some order ->
    let side = Order.side order in
    let price = Order.price order in
    let levels_map = side_levels t side in
    (match Map.find levels_map price with
     | None -> ()
     | Some q ->
       Queue.filter_inplace q ~f:(fun x -> Order.compare x order <> 0);
       (* Drop the price level entirely once its last order leaves, so the
          map only ever holds non-empty levels — recomputing the best off
          [Map.max_elt] / [Map.min_elt] relies on this. *)
       if Queue.is_empty q
       then (
         Map.remove levels_map price |> set_side_levels t side;
         (* Only an emptied BEST level moves the best; removals behind it
            (and removals that leave the level non-empty) don't. This is the
            one place the cache pays a tree lookup. *)
         match best_level_entry t side with
         | Some (best_price, _) ->
           if Price.( = ) price best_price then recompute_best_level t side
         | None -> ()));
    Map.remove t.identifiers order_id |> set_identifiers t;
    Some order
;;

let remove t order_id = ignore (remove' t order_id : Order.t option)
let find t order_id = Map.find t.identifiers order_id

(* Best bid is the highest bid price; best ask is the lowest ask price — read
   straight off the cache, O(1). *)
let best_price (t : t) (side : Side.t) =
  Option.map (best_level_entry t side) ~f:fst
;;

(* The most aggressively priced resting order on the opposite side (lowest
   ask for an incoming buy, highest bid for an incoming sell) is the head of
   the cached best level's queue — arrival order within a level is queue
   order. Confirm it is marketable against the incoming order's price. *)
let find_match t incoming =
  let incoming_side = Order.side incoming in
  let opposite_side = Side.flip incoming_side in
  let candidate =
    match best_level_entry t opposite_side with
    | None -> None
    | Some ((_ : Price.t), queue) -> Queue.peek queue
  in
  match candidate with
  | None -> None
  | Some resting_order ->
    if Price.is_marketable
         incoming_side
         ~resting_price:(Order.price resting_order)
         ~price:(Order.price incoming)
    then Some resting_order
    else None
;;

let orders_on_side t side =
  let assoc_list =
    match side with
    | Side.Buy -> Map.to_alist ~key_order:`Decreasing (side_levels t side)
    | Side.Sell -> Map.to_alist ~key_order:`Increasing (side_levels t side)
  in
  List.concat (List.map assoc_list ~f:(fun (_, q) -> Queue.to_list q))
;;

(* Best price first means increasing keys for asks (lowest ask leads) and
   decreasing keys for bids (highest bid leads). [Map.iter] walks keys in
   increasing order, so asks use it directly; bids reverse the traversal with
   [Map.fold_right]. Each level's queue is already oldest-first. *)
let iter_orders t side ~f =
  match (side : Side.t) with
  | Buy ->
    Map.fold_right t.bids ~init:() ~f:(fun ~key:_ ~data:q () ->
      Queue.iter q ~f)
  | Sell -> Map.iter t.asks ~f:(fun q -> Queue.iter q ~f)
;;

let is_empty t = Map.is_empty t.bids && Map.is_empty t.asks

let count t side =
  Map.fold (side_levels t side) ~init:0 ~f:(fun ~key:_ ~data:value acc ->
    acc + Queue.length value)
;;

(* A level's size is the total shares resting at that price — the sum of
   every order's remaining size — not the number of orders. *)
let level_size q =
  Queue.sum (module Int) q ~f:(fun order ->
    Size.to_int (Order.remaining_size order))
  |> Size.of_int
;;

let best_level t side : Level.t option =
  match best_level_entry t side with
  | None -> None
  | Some (price, queue) -> Some { price; size = level_size queue }
;;

let best_bid_offer t : Bbo.t =
  { bid = best_level t Buy; ask = best_level t Sell }
;;

(* Each map entry is already one price level: the queue of every order
   resting at that price. So aggregating is just summing the queue's
   remaining sizes, and the map's key ordering gives us level ordering for
   free — no sort. Asks want lowest price first, which is the map's natural
   ascending order; bids want highest first, so we walk the keys in
   decreasing order. [find_match] visits levels most-aggressive-first, and
   this matches it. *)
let snapshot_side t (side : Side.t) =
  let key_order =
    match side with Buy -> `Decreasing | Sell -> `Increasing
  in
  Map.to_alist ~key_order (side_levels t side)
  |> List.map ~f:(fun (price, q) -> { Level.price; size = level_size q })
;;

let snapshot t =
  { Book.symbol = symbol t
  ; bids = snapshot_side t Buy
  ; asks = snapshot_side t Sell
  ; bbo = best_bid_offer t
  }
;;

let invariant t =
  List.iter
    Side.[ Buy; Sell ]
    ~f:(fun side ->
      let levels = side_levels t side in
      (* The map never holds an empty level — the cache recompute and the
         snapshot both rely on it. *)
      Map.iteri levels ~f:(fun ~key:price ~data:queue ->
        if Queue.is_empty queue
        then raise_s [%message "empty level in map" (price : Price.t)]);
      (* The cache IS the map's extreme entry — same price, and the very same
         queue object (physical equality: levels mutate in place, so a copy
         would go stale on the next fill). *)
      let extreme =
        match (side : Side.t) with
        | Buy -> Map.max_elt levels
        | Sell -> Map.min_elt levels
      in
      match best_level_entry t side, extreme with
      | None, None -> ()
      | Some (price, _), None ->
        raise_s
          [%message
            "cache set but side is empty" (side : Side.t) (price : Price.t)]
      | None, Some (price, _) ->
        raise_s
          [%message
            "cache empty but side is not" (side : Side.t) (price : Price.t)]
      | Some (cached_price, cached_queue), Some (map_price, map_queue) ->
        if not (Price.( = ) cached_price map_price)
        then
          raise_s
            [%message
              "cached best price is stale"
                (side : Side.t)
                (cached_price : Price.t)
                (map_price : Price.t)];
        if not (phys_equal cached_queue map_queue)
        then
          raise_s
            [%message
              "cached best queue is not the map's queue"
                (side : Side.t)
                (cached_price : Price.t)])
;;

module For_testing = struct
  let remove = remove'
  let invariant = invariant
end
