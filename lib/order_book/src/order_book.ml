open! Core
open Jsip_types
open Async_log_kernel.Ppx_log_syntax

type t =
  { symbol : Symbol.t
  ; mutable bids : Order.t Queue.t Price.Map.t
  ; mutable asks : Order.t Queue.t Price.Map.t
  ; mutable identifiers : Order.t Order_id.Map.t
  ; mutable best_bid : Price.t option
  ; mutable best_ask : Price.t option
  }
[@@deriving sexp_of]

let create symbol =
  { symbol
  ; bids = Price.Map.empty
  ; asks = Price.Map.empty
  ; identifiers = Order_id.Map.empty
  ; best_bid = None
  ; best_ask = None
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

let update_best t order =
  let side = Order.side order in
  let price = Order.price order in
  match side with
  | Buy ->
    (match t.best_bid with
     | None -> t.best_bid <- Some price
     | Some bid ->
       if Price.compare price bid = 1 then t.best_bid <- Some price else ())
  | Sell ->
    (match t.best_bid with
     | None -> t.best_bid <- Some price
     | Some bid ->
       if Price.compare price bid = -1 then t.best_ask <- Some price else ())
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
  | Some prices ->
    Queue.enqueue prices order;
    update_best t order
;;

let remove t order_id =
  let order = Map.find t.identifiers order_id in
  match order with
  | None -> ()
  | Some order ->
    let side = Order.side order in
    let price = Order.price order in
    let levels_map = side_levels t side in
    let price_level = Map.find levels_map price in
    (match price_level with
     | None -> ()
     | Some q ->
       Queue.filter_inplace q ~f:(fun x -> Order.compare x order <> 0));
    Map.remove t.identifiers order_id |> set_identifiers t
  
    let best_level = best_level t Order.side order in (match best_level with 
    | None -> 
    | Some {price = price} )
;;

let find t order_id = Map.find t.identifiers order_id

(* Scan the opposite side for the most aggressively priced resting order
   (lowest ask for an incoming buy, highest bid for an incoming sell), with
   ties broken by arrival time (lower order id = arrived first), then confirm
   it is marketable against the incoming order's price. *)
let find_match t incoming =
  let incoming_side = Order.side incoming in
  let candidate = best_price t incoming_side in 
  match candid


  let opposite_side = Side.flip incoming_side in
  let candidate_order =
    List.reduce
      (side_levels t opposite_side)
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

let orders_on_side t side = side_levels t side
let is_empty t = Map.is_empty t.bids && Map.is_empty t.asks

let count t side =
  Map.fold (side_levels t side) ~init:0 ~f:(fun ~key:_ ~data:value acc ->
    acc + Queue.length value)
;;

let best_price t side =
  let side_levels = side_levels t side in
  match side with
  | Buy ->
    (match t.best_bid with
     | None -> None
     | Some curr_best ->
       let best_binding = Map.max_elt side_levels in
       (match best_binding with
        | Some (best_price, _) ->
          if Price.is_more_aggressive side ~price:best_price ~than:curr_best
          then (
            t.best_bid <- Some best_price;
            Some best_price)
          else Some curr_best
        | None -> t.best_bid))
  | Sell ->
    (match t.best_ask with
     | None -> None
     | Some curr_best ->
       let best_binding = Map.min_elt side_levels in
       (match best_binding with
        | Some (best_price, _) ->
          if Price.is_more_aggressive side ~price:best_price ~than:curr_best
          then (
            t.best_ask <- Some best_price;
            Some best_price)
          else Some curr_best
        | None -> t.best_bid))
;;

let best_level t side : Level.t option =
  let side_levels = side_levels t side in
  match best_price t side with
  | None -> None
  | Some price ->
    let total_size =
      match Map.find side_levels price with
      | None -> 0
      | Some q -> Queue.length q
    in
    Some { price; size = Size.of_int total_size }
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
