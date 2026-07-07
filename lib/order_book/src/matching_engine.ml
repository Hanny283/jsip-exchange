open! Core
open Jsip_types

type t =
  { books : Order_book.t Symbol.Map.t
  ; order_id_gen : Order_id.Generator.t
  ; mutable next_fill_id : int
  ; client_orders : Order.t Client_order_id.Table.t Participant.Table.t
  }
[@@deriving sexp_of]

let create symbols =
  let books =
    List.map symbols ~f:(fun sym -> sym, Order_book.create sym)
    |> Symbol.Map.of_alist_exn
  in
  { books
  ; order_id_gen = Order_id.Generator.create ()
  ; next_fill_id = 1
  ; client_orders = Participant.Table.create ()
  }
;;

let book t symbol = Map.find t.books symbol

(** Run the matching loop: repeatedly find a compatible resting order and
    fill against it. Returns the list of Fill and Trade_report events
    produced, the next fill_id to use, and whether matching stopped because
    the next fill would have been against the aggressor's own resting order
    (in which case the caller must cancel the aggressor's remainder rather
    than let it trade or rest). *)
let rec match_loop ~book ~order ~fill_id =
  if Size.( <= ) (Order.remaining_size order) Size.zero
  then [], fill_id, `No_self_trade
  else (
    match Order_book.find_match book order with
    | None -> [], fill_id, `No_self_trade
    | Some resting
      when Participant.equal
             (Order.participant resting)
             (Order.participant order) -> [], fill_id, `Would_self_trade
    | Some resting ->
      let fill_size =
        Size.min (Order.remaining_size order) (Order.remaining_size resting)
      in
      Order.fill order ~by:fill_size;
      Order.fill resting ~by:fill_size;
      if Order.is_fully_filled resting
      then Order_book.remove book (Order.order_id resting);
      let fill_event =
        Exchange_event.Fill
          { fill_id
          ; symbol = Order.symbol order
          ; price = Order.price resting
          ; size = fill_size
          ; aggressor_order_id = Order.order_id order
          ; aggressor_participant = Order.participant order
          ; aggressor_side = Order.side order
          ; resting_order_id = Order.order_id resting
          ; resting_participant = Order.participant resting
          ; aggressor_client_order_id = Order.client_order_id order
          ; resting_client_order_id = Order.client_order_id resting
          }
      in
      let trade_event =
        Exchange_event.Trade_report
          { symbol = Order.symbol order
          ; price = Order.price resting
          ; size = fill_size
          }
      in
      let remaining_events, next_fill_id, self_trade =
        match_loop ~book ~order ~fill_id:(fill_id + 1)
      in
      fill_event :: trade_event :: remaining_events, next_fill_id, self_trade)
;;

let submit t (request : Order.Request.t) =
  match Map.find t.books request.symbol with
  | None ->
    [ Exchange_event.Order_reject { request; reason = "unknown symbol" } ]
  | Some book ->
    let client_orders =
      Hashtbl.find_or_add
        t.client_orders
        request.participant
        ~default:(fun () -> Client_order_id.Table.create ())
    in
    (match Hashtbl.find client_orders request.client_order_id with
     | Some _ ->
       (* The client has already used this id; reject rather than accept a
          second order under the same handle. *)
       [ Exchange_event.Order_reject
           { request; reason = "duplicate client order id" }
       ]
     | None ->
       let order_id = Order_id.Generator.next t.order_id_gen in
       let order = Order.create request ~order_id in
       Hashtbl.set client_orders ~key:request.client_order_id ~data:order;
       let accepted = Exchange_event.Order_accept { order_id; request } in
       (* Snapshot BBO before matching so we can detect changes. *)
       let bbo_before = Order_book.best_bid_offer book in
       (* Match *)
       let fill_events, next_fill_id, self_trade =
         match_loop ~book ~order ~fill_id:t.next_fill_id
       in
       t.next_fill_id <- next_fill_id;
       (* Post-match: rest on book or cancel unfilled remainder. *)
       let cancel_remainder reason =
         Exchange_event.Order_cancel
           { order_id
           ; participant = Order.participant order
           ; symbol = Order.symbol order
           ; remaining_size = Order.remaining_size order
           ; reason
           ; client_order_id = request.client_order_id
           }
       in
       let post_events =
         if Size.( > ) (Order.remaining_size order) Size.zero
         then (
           match self_trade with
           | `Would_self_trade ->
             (* The next match would have been against the participant's own
                resting order; cancel the aggressor instead of letting it
                trade or rest (the resting order is untouched). *)
             [ cancel_remainder Self_trade_prevention ]
           | `No_self_trade ->
             (match Order.time_in_force order with
              | Day ->
                Order_book.add book order;
                []
              | Ioc -> [ cancel_remainder Ioc_remainder ]))
         else []
       in
       (* Emit BBO update if the best bid or ask changed. *)
       let bbo_after = Order_book.best_bid_offer book in
       let bbo_events =
         if Bbo.equal bbo_before bbo_after
         then []
         else
           [ Exchange_event.Best_bid_offer_update
               { symbol = Order.symbol order; bbo = bbo_after }
           ]
       in
       List.concat [ [ accepted ]; fill_events; post_events; bbo_events ])
;;

let cancel t ~participant ~client_order_id =
  let order =
    match Hashtbl.find t.client_orders participant with
    | None -> None
    | Some client_orders -> Hashtbl.find client_orders client_order_id
  in
  match order with
  | None ->
    [ Exchange_event.Cancel_reject
        { participant; client_order_id; reason = "order not found" }
    ]
  | Some order ->
    let symbol = Order.symbol order in
    (match Map.find t.books symbol with
     | None ->
       [ Exchange_event.Cancel_reject
           { participant; client_order_id; reason = "order not found" }
       ]
     | Some book ->
       (match Order_book.find book (Order.order_id order) with
        | None ->
          [ Exchange_event.Cancel_reject
              { participant
              ; client_order_id
              ; reason = "order already filled or cancelled"
              }
          ]
        | Some _ ->
          let bbo_before = Order_book.best_bid_offer book in
          Order_book.remove book (Order.order_id order);
          let cancelled =
            Exchange_event.Order_cancel
              { order_id = Order.order_id order
              ; participant
              ; symbol
              ; remaining_size = Order.remaining_size order
              ; reason = Participant_requested
              ; client_order_id
              }
          in
          let bbo_after = Order_book.best_bid_offer book in
          let bbo_events =
            if Bbo.equal bbo_before bbo_after
            then []
            else
              [ Exchange_event.Best_bid_offer_update
                  { symbol; bbo = bbo_after }
              ]
          in
          cancelled :: bbo_events))
;;
