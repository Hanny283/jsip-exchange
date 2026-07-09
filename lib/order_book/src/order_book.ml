open! Core
open Jsip_types

type t =
  { symbol : Symbol.t
  ; mutable bids : Order.t Queue.t Price.Map.t
  ; mutable asks : Order.t Queue.t Price.Map.t
  ; mutable identifiers : Order.t Order_id.Map.t
  }
[@@deriving sexp_of]

let create symbol =
  { symbol
  ; bids = Price.Map.empty
  ; asks = Price.Map.empty
  ; identifiers = Order_id.Map.empty
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

let add t order =
  let order_id = Order.order_id order in
  Map.set t.identifiers ~key:order_id ~data:order |> set_identifiers t;
  let side = Order.side order in
  let levels = side_levels t side in
  let list = Map.find levels (Order.price order) in
  match list with
  | None ->
    let q = Queue.create () in
    Queue.enqueue q order;
    Map.add_exn levels ~key:(Order.price order) ~data:q
    |> set_side_levels t side
  | Some prices -> Queue.enqueue prices order
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
          map only ever holds non-empty levels — [best_price] relies on this
          to read the true best off [Map.max_elt] / [Map.min_elt]. *)
       if Queue.is_empty q
       then Map.remove levels_map price |> set_side_levels t side);
    Map.remove t.identifiers order_id |> set_identifiers t;
    Some order
;;

let remove t order_id = ignore (remove' t order_id : Order.t option)
let find t order_id = Map.find t.identifiers order_id

(* Best bid is the highest bid price; best ask is the lowest ask price.
   Levels are pruned on removal, so the extremal map key always corresponds
   to a non-empty queue of resting orders. *)
let best_price (t : t) (side : Side.t) =
  match side with
  | Buy -> Option.map (Map.max_elt t.bids) ~f:fst
  | Sell -> Option.map (Map.min_elt t.asks) ~f:fst
;;

(* Scan the opposite side for the most aggressively priced resting order
   (lowest ask for an incoming buy, highest bid for an incoming sell), with
   ties broken by arrival time (lower order id = arrived first), then confirm
   it is marketable against the incoming order's price. *)
let find_match t incoming =
  let incoming_side = Order.side incoming in
  let opposite_side = Side.flip incoming_side in
  let levels_map = side_levels t opposite_side in
  let candidate_price = best_price t opposite_side in
  let candidate =
    match candidate_price with
    | None -> None
    | Some price ->
      let q = Map.find levels_map price in
      (match q with None -> None | Some queue -> Queue.peek queue)
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
  let side_levels = side_levels t side in
  match best_price t side with
  | None -> None
  | Some price ->
    let size =
      match Map.find side_levels price with
      | None -> Size.of_int 0
      | Some q -> level_size q
    in
    Some { price; size }
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

module For_testing = struct
  let remove = remove'
end
