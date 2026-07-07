open! Core
open! Async
open Jsip_types
module Context = Jsip_bot_runtime.Bot_runtime.Context

(* A pathological bot that simulates an abusive exchange participant. Rather
   than trading with any strategy, it hammers the exchange with large bursts
   of orders on every tick, deliberately stressing three shared resources:

   - the server's bounded request queue (submissions pile up faster than the
     single matching loop can drain them),
   - the dispatcher's per-event fan-out work, and
   - the (unbounded) subscriber pipes every accept / BBO / trade event is
     written to.

   The spammer is a strategy-free flood: it never tracks a position and does
   not try to make money. Its cousin {!Pump_and_dump} -- a stateful price
   manipulation that started life as a second behavior of this bot -- lives
   in its own module. *)

module Config = struct
  type t =
    { symbols : Symbol.t list
    ; orders_per_burst : int
        (* Orders fired in a single tight burst per tick -- the core stress
           lever. Combined with a small tick interval this pins the request
           queue and floods every subscriber pipe. *)
    ; buy_chance : Percent.t
        (* Probability an order is a buy. 50% is balanced; skewing it leans
           on one side of the book (a crude directional-pressure knob; for
           real directional manipulation see {!Pump_and_dump}). *)
    ; marketable_chance : Percent.t
        (* Probability an order crosses the spread and trades immediately
           (generating fills, and therefore extra session and trade-report
           fan-out) rather than resting in the book. *)
    ; time_in_force_distribution : Time_in_force.t Bot_random.distribution
        (* Distribution the order's time-in-force is drawn from. Expressed
           over all of {!Time_in_force.t} so new order types slot in as new
           weighted entries. Resting [Day] orders pile up in the book; [Ioc]
           orders churn the matching loop. *)
    ; mean_size : int (* Center of the per-order size distribution. *)
    ; price_jitter_cents : int
        (* Half-width of the uniform price band around the reference price,
           so the burst spreads across many price levels. *)
    ; generator : Client_order_id.Generator.t
    ; bbo_cache : Bbo.t Symbol.Table.t
    }

  let create
    ~symbols
    ~orders_per_burst
    ~buy_chance
    ~marketable_chance
    ~time_in_force_distribution
    ~mean_size
    ~price_jitter_cents
    =
    { symbols
    ; orders_per_burst
    ; buy_chance
    ; marketable_chance
    ; time_in_force_distribution
    ; mean_size
    ; price_jitter_cents
    ; generator = Client_order_id.Generator.create ()
    ; bbo_cache = Symbol.Table.create ()
    }
  ;;
end

let name = "Spammer"

(* Smallest amount by which a "marketable" order crosses past the opposite
   best price, so it is guaranteed to trade rather than sit at the touch. *)
let cross_cents = 1

let random_size rng ~mean_size =
  let half = Int.max 1 (mean_size / 2) in
  let lo = Int.max 1 (mean_size - half) in
  let hi = mean_size + half in
  Size.of_int (Splittable_random.int rng ~lo ~hi)
;;

(* Reference price for [side]'s own best, taken from the last BBO we cached;
   falls back to the fundamental when that side of the book is empty. *)
let reference_price (config : Config.t) context symbol ~side =
  let cached =
    let%bind.Option bbo = Hashtbl.find config.bbo_cache symbol in
    Bbo.price bbo side
  in
  match cached with
  | Some price -> Price.to_int_cents price
  | None -> Price.to_int_cents (Context.fundamental context symbol)
;;

(* Choose a price for an order. A marketable order crosses the *opposite*
   best (so it trades); a resting order sits a few cents away from *this*
   side's best (so it stays on the book). Random jitter spreads the burst
   across price levels. *)
let choose_price (config : Config.t) context symbol ~side ~marketable rng =
  let jitter =
    Splittable_random.int rng ~lo:0 ~hi:config.price_jitter_cents
  in
  let cents =
    match marketable with
    | true ->
      let opposite =
        reference_price config context symbol ~side:(Side.flip side)
      in
      (match side with
       | Side.Buy -> opposite + cross_cents + jitter
       | Sell -> opposite - cross_cents - jitter)
    | false ->
      let own = reference_price config context symbol ~side in
      (match side with
       | Side.Buy -> own - cross_cents - jitter
       | Sell -> own + cross_cents + jitter)
  in
  Price.of_int_cents (Int.max 1 cents)
;;

let random_request (config : Config.t) context rng =
  let symbol = Bot_random.uniform_exn rng config.symbols in
  let side =
    if Bot_random.does_occur rng config.buy_chance then Side.Buy else Sell
  in
  let size = random_size rng ~mean_size:config.mean_size in
  let marketable = Bot_random.does_occur rng config.marketable_chance in
  let price = choose_price config context symbol ~side ~marketable rng in
  let time_in_force =
    Bot_random.categorically_weighted_exn
      rng
      config.time_in_force_distribution
  in
  ({ client_order_id = Client_order_id.Generator.next config.generator
   ; symbol
   ; participant = Context.participant context
   ; side
   ; price
   ; size
   ; time_in_force
   }
   : Order.Request.t)
;;

let on_start (_config : Config.t) _context = Deferred.unit

(* Fire the whole burst at once. We intentionally do NOT submit one order per
   tick: [~how:`Parallel] launches every submission concurrently so the burst
   lands as a tight cluster, maximizing pressure on the request queue and the
   dispatcher fan-out. Backpressure from the bounded request queue naturally
   couples the burst rate to the matching loop's drain rate. *)
let on_tick (config : Config.t) context =
  let rng = Context.random context in
  Deferred.List.iter
    ~how:`Parallel
    (List.init config.orders_per_burst ~f:Fn.id)
    ~f:(fun _ ->
      Deferred.ignore_m
        (Context.submit context (random_request config context rng)))
;;

(* Cache every BBO for price reference; the flood ignores everything else. *)
let on_event (config : Config.t) _context (event : Exchange_event.t) =
  (match event with
   | Best_bid_offer_update { symbol; bbo } ->
     Hashtbl.set config.bbo_cache ~key:symbol ~data:bbo
   | Order_accept _ | Fill _ | Order_cancel _ | Order_reject _
   | Cancel_reject _ | Trade_report _ ->
     ());
  Deferred.unit
;;
