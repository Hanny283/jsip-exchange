open! Core
open Jsip_types
open Async_log_kernel.Ppx_log_syntax


module PriceMap  


type t =
  { symbol : Symbol.t
  ; mutable bids : (Price.t * Map
  ; mutable asks : Order.t Map 
  }
[@@deriving sexp_of]

let create symbol = { symbol; bids = []; asks = [] }
let symbol t = t.symbol

let side_list t side =
  match (side : Side.t) with Buy -> t.bids | Sell -> t.asks
;;

let set_side_list t side orders =
  match (side : Side.t) with
  | Buy -> t.bids <- orders
  | Sell -> t.asks <- orders
;;

let add t order =
  let side = Order.side order in
  set_side_list t side (order :: side_list t side)
;;

let remove' t order_id =
  let remove_from t side order_id =
    let orders = side_list t side in
    match
      List.partition_tf orders ~f:(fun o ->
        Order_id.equal (Order.order_id o) order_id)
    with
    | [], _ -> None
    | [ found ], rest ->
      set_side_list t side rest;
      Some found
    | matches, _ ->
      [%log.info
        "BUG: More than one order matching order_id found when removing"
          (order_id : Order_id.t)
          (matches : Order.t list)
          (t.symbol : Symbol.t)
          (side : Side.t)];
      None
  in
  match remove_from t Buy order_id with
  | Some _ as result -> result
  | None -> remove_from t Sell order_id
;;

let remove t order_id = ignore (remove' t order_id : Order.t option)

let find t order_id =
  let find_in side =
    List.find (side_list t side) ~f:(fun o ->
      Order_id.equal (Order.order_id o) order_id)
  in
  match find_in Buy with Some _ as result -> result | None -> find_in Sell
;;

(* Scan the opposite side for the most aggressively priced resting order
   (lowest ask for an incoming buy, highest bid for an incoming sell), with
   ties broken by arrival time (lower order id = arrived first), then confirm
   it is marketable against the incoming order's price. *)
let find_match t incoming =
  let incoming_side = Order.side incoming in
  let opposite_side = Side.flip incoming_side in
  let candidate_order =
    List.reduce
      (side_list t opposite_side)
      ~f:(fun best_order_so_far next_order ->
        if not
             (Price.( = )
                (Order.price best_order_so_far)
                (Order.price next_order))
        then
          (* Pick the most aggressive resting order from the resting side's
             own perspective: lowest ask for an incoming buy, highest bid for
             an incoming sell. *)
          if Price.is_more_aggressive
               opposite_side
               ~price:(Order.price best_order_so_far)
               ~than:(Order.price next_order)
          then best_order_so_far
          else next_order
        else if Order_id.( < )
                  (Order.order_id best_order_so_far)
                  (Order.order_id next_order)
        then best_order_so_far
        else next_order)
  in
  (* The most aggressive resting order is the only one worth checking: if it
     isn't marketable, nothing on this side crosses. *)
  match candidate_order with
  | Some order ->
    if Price.is_marketable
         incoming_side
         ~price:(Order.price incoming)
         ~resting_price:(Order.price order)
    then Some order
    else None
  | None -> None
;;

let orders_on_side t side = side_list t side
let is_empty t = List.is_empty t.bids && List.is_empty t.asks
let count t side = List.length (side_list t side)

let best_price t side =
  let price_list = List.map (side_list t side) ~f:Order.price in
  List.reduce price_list ~f:(fun best_price_so_far next_price ->
    if Price.is_more_aggressive
         side
         ~price:best_price_so_far
         ~than:next_price
    then best_price_so_far
    else next_price)
;;

let best_level t side : Level.t option =
  match best_price t side with
  | None -> None
  | Some price ->
    let total_size =
      List.fold (side_list t side) ~init:Size.zero ~f:(fun acc order ->
        if Price.equal (Order.price order) price
        then Size.( + ) acc (Order.remaining_size order)
        else acc)
    in
    Some { price; size = total_size }
;;

let best_bid_offer t : Bbo.t =
  { bid = best_level t Buy; ask = best_level t Sell }
;;

(* Sort the underlying orders by price-time priority first, then project to
   levels. Sorting [Level.t]s directly would lose arrival time, since a level
   carries only price and size. *)
let snapshot_side t (side : Side.t) =
  let compare resting1 resting2 =
    let price1 = Order.price resting1 in
    let price2 = Order.price resting2 in
    let id1 = Order.order_id resting1 in
    let id2 = Order.order_id resting2 in
    if not (Price.( = ) price1 price2)
    then
      (* Most aggressive first: highest bids / lowest asks lead the snapshot,
         matching the order [find_match] visits them. *)
      if Price.is_more_aggressive side ~price:price1 ~than:price2
      then -1
      else 1
    else [%compare: Order_id.t] id1 id2
  in
  orders_on_side t side |> List.sort ~compare |> List.map ~f:Level.of_order
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
