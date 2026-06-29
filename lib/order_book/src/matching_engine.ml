open! Core
open Jsip_types

type t =
  { books : Order_book.t Symbol.Map.t
  ; order_id_gen : Order_id.Generator.t
  ; mutable next_fill_id : int
  ; (* Every order the engine has ever accepted, keyed by its owning
       participant and the client-assigned id. This is the lookup behind both
       duplicate detection (1e) and cancellation (1f). Entries are never
       removed: a client order id stays reserved for the life of the engine,
       even after the order fills or cancels, so ids can't be reused. Whether
       an order is still live is answered by the book, not by this table. *)
    client_orders : Order.t Client_order_id.Table.t Participant.Table.t
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
    produced, and the next fill_id to use. *)
let rec match_loop ~book ~order ~fill_id =
  if Size.( <= ) (Order.remaining_size order) Size.zero
  then [], fill_id
  else (
    match Order_book.find_match book order with
    | None -> [], fill_id
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
      let remaining_events, next_fill_id =
        match_loop ~book ~order ~fill_id:(fill_id + 1)
      in
      fill_event :: trade_event :: remaining_events, next_fill_id)
;;

let submit t (request : Order.Request.t) =
  match Map.find t.books request.symbol with
  | None ->
    [ Exchange_event.Order_reject { request; reason = "unknown symbol" } ]
  | Some book ->
    let client_orders =
      Hashtbl.find_or_add t.client_orders request.participant ~default:(fun () ->
        Client_order_id.Table.create ())
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
       let fill_events, next_fill_id =
         match_loop ~book ~order ~fill_id:t.next_fill_id
       in
       t.next_fill_id <- next_fill_id;
       (* Post-match: rest on book or cancel unfilled remainder. *)
       let post_events =
         if Size.( > ) (Order.remaining_size order) Size.zero
         then (
           match Order.time_in_force order with
           | Day ->
             Order_book.add book order;
             []
           | Ioc ->
             [ Exchange_event.Order_cancel
                 { order_id
                 ; participant = Order.participant order
                 ; symbol = Order.symbol order
                 ; remaining_size = Order.remaining_size order
                 ; reason = Ioc_remainder
                 ; client_order_id = request.client_order_id
                 }
             ])
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

(* Cancel the order identified by [(participant, client_order_id)] — the same
   handle the client used to submit it. The id is looked up in [client_orders]
   and the live order found in its book; a still-resting order is removed and
   reported with [Order_cancel] (plus a BBO update if the best price moved). An
   id that was never used, or whose order has already left the book (filled or
   previously cancelled), yields [Cancel_reject]. *)
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
              [ Exchange_event.Best_bid_offer_update { symbol; bbo = bbo_after }
              ]
          in
          cancelled :: bbo_events))
;;
