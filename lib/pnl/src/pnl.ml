open! Core
open Jsip_types

(* One participant's holding in one symbol. [cost_basis_cents] is the signed
   total cost of the currently-open position: for a long it is the cash paid
   in, for a short it is negative (cash received). Dividing it by the signed
   [inventory] recovers a positive average entry price for either direction. *)
module Position = struct
  type t =
    { inventory : int
    ; cost_basis_cents : int
    ; realized_cents : int
    }

  let empty = { inventory = 0; cost_basis_cents = 0; realized_cents = 0 }

  let average_entry_cents t =
    match t.inventory with
    | 0 -> None
    | inventory -> Some (t.cost_basis_cents / inventory)
  ;;
end

type t =
  { positions : Position.t Symbol.Map.t Participant.Map.t
  ; reference_prices : Price.t Symbol.Map.t
  }

let empty =
  { positions = Participant.Map.empty; reference_prices = Symbol.Map.empty }
;;

(* Cash realized by trading [trade_shares] signed shares (positive = buy,
   negative = sell) at [trade_price] against a position that currently holds
   [shares] signed shares entered at [average_entry_price]. All prices are in
   cents.

   Opening a new position or adding to an existing one realizes nothing — the
   cash only becomes real when a position is closed or reduced. This function
   decides how much of [trade_shares] closes the existing position and what
   that closed slice is worth.

   The shape mirrors the unrealized formula
   [shares * (reference_price - average_entry_price)] — here the trade price
   plays the role the reference price plays there.

   TODO(human): implement the realized-P&L rule. *)
let realized_cents_of_reduction
  ~shares
  ~average_entry_price
  ~trade_shares
  ~trade_price
  =
  let closed = Int.min (Int.abs trade_shares) (Int.abs shares) in
  Sign.to_int (Int.sign shares) * closed * (trade_price - average_entry_price)
;;

(* Apply a single signed trade to one position: update realized cash,
   inventory, and cost basis. The cost-basis bookkeeping mirrors the realized
   rule — opens/extensions roll the trade into the basis; reductions keep the
   average entry fixed; a flip past zero re-opens the leftover at the trade
   price. *)
let apply_signed_trade (pos : Position.t) ~trade_qty ~trade_price_cents =
  let inventory = pos.inventory in
  let is_opening =
    inventory = 0 || Bool.equal (inventory > 0) (trade_qty > 0)
  in
  let realized_delta =
    if is_opening
    then 0
    else
      realized_cents_of_reduction
        ~shares:inventory
        ~average_entry_price:(pos.cost_basis_cents / inventory)
        ~trade_shares:trade_qty
        ~trade_price:trade_price_cents
  in
  let new_inventory = inventory + trade_qty in
  let new_cost_basis_cents =
    if is_opening
    then pos.cost_basis_cents + (trade_qty * trade_price_cents)
    else if new_inventory = 0
    then 0
    else if Bool.equal (new_inventory > 0) (inventory > 0)
    then
      (* partial reduction: same average entry on the remainder *)
      pos.cost_basis_cents / inventory * new_inventory
    else
      (* flipped past flat: the leftover is a fresh position *)
      new_inventory * trade_price_cents
  in
  { Position.inventory = new_inventory
  ; cost_basis_cents = new_cost_basis_cents
  ; realized_cents = pos.realized_cents + realized_delta
  }
;;

let position t ~participant ~symbol =
  Map.find t.positions participant
  |> Option.bind ~f:(fun by_symbol -> Map.find by_symbol symbol)
  |> Option.value ~default:Position.empty
;;

let set_position t ~participant ~symbol position =
  let by_symbol =
    Map.find t.positions participant
    |> Option.value ~default:Symbol.Map.empty
    |> Map.set ~key:symbol ~data:position
  in
  { t with positions = Map.set t.positions ~key:participant ~data:by_symbol }
;;

let apply_one t ~participant ~symbol ~side ~size ~price_cents =
  let trade_qty = Side.sign side * size in
  let position =
    apply_signed_trade
      (position t ~participant ~symbol)
      ~trade_qty
      ~trade_price_cents:price_cents
  in
  set_position t ~participant ~symbol position
;;

let apply_fill t (fill : Fill.t) =
  let price_cents = Price.to_int_cents fill.price in
  let size = Size.to_int fill.size in
  let symbol = fill.symbol in
  (* The aggressor trades on its own side; the resting order takes the
     opposite side of the same trade. *)
  apply_one
    t
    ~participant:fill.aggressor_participant
    ~symbol
    ~side:fill.aggressor_side
    ~size
    ~price_cents
  |> fun t ->
  apply_one
    t
    ~participant:fill.resting_participant
    ~symbol
    ~side:(Side.flip fill.aggressor_side)
    ~size
    ~price_cents
;;

let apply_trade_report t (event : Exchange_event.t) =
  match event with
  | Trade_report { symbol; price; size = _ } ->
    { t with
      reference_prices = Map.set t.reference_prices ~key:symbol ~data:price
    }
  | Order_accept _ | Fill _ | Order_cancel _ | Order_reject _
  | Cancel_reject _ | Best_bid_offer_update _ ->
    t
;;

module Summary = struct
  module Per_symbol = struct
    type t =
      { symbol : Symbol.t
      ; inventory : int
      ; average_entry : Price.t option
      ; reference_price : Price.t option
      ; realized_cents : int
      ; unrealized_cents : int
      }
    [@@deriving sexp_of]
  end

  type t =
    { per_symbol : Per_symbol.t list
    ; total_realized_cents : int
    ; total_unrealized_cents : int
    }
  [@@deriving sexp_of]
end

let summary t participant : Summary.t =
  let by_symbol =
    Map.find t.positions participant
    |> Option.value ~default:Symbol.Map.empty
  in
  let per_symbol =
    Map.to_alist by_symbol
    |> List.map ~f:(fun (symbol, (pos : Position.t)) ->
      let average_entry_cents = Position.average_entry_cents pos in
      let reference_price = Map.find t.reference_prices symbol in
      let unrealized_cents =
        match average_entry_cents, reference_price with
        | Some avg, Some reference_price ->
          pos.inventory * (Price.to_int_cents reference_price - avg)
        | None, _ | _, None -> 0
      in
      { Summary.Per_symbol.symbol
      ; inventory = pos.inventory
      ; average_entry = Option.map average_entry_cents ~f:Price.of_int_cents
      ; reference_price
      ; realized_cents = pos.realized_cents
      ; unrealized_cents
      })
  in
  { Summary.per_symbol
  ; total_realized_cents =
      List.sum (module Int) per_symbol ~f:(fun p -> p.realized_cents)
  ; total_unrealized_cents =
      List.sum (module Int) per_symbol ~f:(fun p -> p.unrealized_cents)
  }
;;
