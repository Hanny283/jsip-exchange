open! Core
open! Async
open Jsip_types
module Bot_runtime = Jsip_bot_runtime.Bot_runtime

module Config = struct
  type t =
    { symbols : Symbol_id.t list
    ; orders_per_burst : int
    ; order_size : Size.t
    ; latest_bbo : Bbo.t Symbol_id.Table.t
    ; mutable next_client_order_id : int
    }

  let create ~symbols ~orders_per_burst ~order_size =
    { symbols
    ; orders_per_burst
    ; order_size
    ; latest_bbo = Symbol_id.Table.create ()
    ; next_client_order_id = 0
    }
  ;;
end

let name = "quote-stuffer"
let on_start (_ : Config.t) (_ : Bot_runtime.Context.t) = return ()

(* Cache the freshest BBO per symbol so [on_tick] has something to peg
   against. Every other event is irrelevant to this bot: it never reacts to
   its own accepts, rejects, or (nonexistent) fills. *)
let on_event
  (config : Config.t)
  (_ : Bot_runtime.Context.t)
  (event : Exchange_event.t)
  =
  (match event with
   | Best_bid_offer_update { symbol; bbo } ->
     Hashtbl.set config.latest_bbo ~key:symbol ~data:bbo
   | Order_accept _ | Fill _ | Order_cancel _ | Order_reject _
   | Trade_report _ | Cancel_reject _ ->
     ());
  return ()
;;

(* Allocate a fresh [client_order_id] and submit one tiny resting Day order
   at [price] on [side]. A distinct id per order is mandatory: the matching
   engine permanently rejects a reused id, so recycling would silently kill
   every submit after the first. *)
let submit_one (config : Config.t) ctx ~symbol ~side ~price =
  let id = config.next_client_order_id in
  config.next_client_order_id <- config.next_client_order_id + 1;
  let request : Order.Request.t =
    { symbol
    ; side
    ; price
    ; size = config.order_size
    ; time_in_force = Day
    ; client_order_id = Client_order_id.of_int id
    }
  in
  match%map Bot_runtime.Context.submit ctx request with
  | Ok () -> () (*[%log.info "quote_stuffed"]*)
  | Error e -> [%log.error "quote_stuffer: submit failed" (e : Error.t)]
;;

let on_tick (config : Config.t) ctx =
  Deferred.List.iter ~how:`Sequential config.symbols ~f:(fun symbol ->
    match Hashtbl.find config.latest_bbo symbol with
    | None ->
      (* No two-sided market cached yet — nothing to peg against. *)
      return ()
    | Some bbo ->
      (* [burst ~side ~price] fires [orders_per_burst] tiny orders at one
         price. Call it once per side from your placement logic below. *)
      let burst ~side ~price =
        Deferred.List.iter
          ~how:`Sequential
          (List.init config.orders_per_burst ~f:Fn.id)
          ~f:(fun (_ : int) -> submit_one config ctx ~symbol ~side ~price)
      in
      (* Peg one tick INSIDE the opposite quote so every order rests just
         short of marketable: buy one tick below the best ask, sell one tick
         above the best bid. If either side of the BBO is empty there is
         nothing to peg to, so skip this symbol. *)
      (* matched on both because we need both best_bid and best_ask at the
         same time, so cannot use Option.iter or Option.map *)
      (match Bbo.price bbo Buy, Bbo.price bbo Sell with
       | None, _ | _, None -> return ()
       | Some best_bid, Some best_ask ->
         let one_tick = Price.of_int_cents 1 in
         let buy_price = Price.( - ) best_ask one_tick in
         let sell_price = Price.( + ) best_bid one_tick in
         let%bind () = burst ~side:Buy ~price:buy_price in
         burst ~side:Sell ~price:sell_price))
;;
