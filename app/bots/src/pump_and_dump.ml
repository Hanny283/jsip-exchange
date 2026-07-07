open! Core
open! Async
open Jsip_types
module Context = Jsip_bot_runtime.Bot_runtime.Context

(* A stateful two-phase manipulation of a single symbol: walk the price up on
   marketable buys ([Accumulate]), then dump the accumulated inventory into
   whoever chased the move ([Distribute]). Every decision is driven by
   observed market data (the cached BBO), never the fundamental oracle, so
   the bot exits on the same information a real manipulator would have. *)

module Phase = struct
  (* Phase-scoped state lives on the constructor that uses it, so states
     like "accumulating with no anchor" or "a tick budget outside
     [Accumulate]" are unrepresentable. *)
  type t =
    | Awaiting_anchor (* no two-sided market seen yet; not trading *)
    | Accumulate of
        { anchor_cents : int
          (* Reference price: mid of the first two-sided BBO observed. *)
        ; ticks_in_phase : int
          (* Ticks spent accumulating, checked against [give_up_ticks]. *)
        } (* buying, to walk the price up *)
    | Distribute (* dumping the accumulated inventory *)
    | Done (* flat; the scheme has run its course *)
  [@@deriving sexp_of]
end

(* The fill-driven accounting, pulled into one immutable value with a pure
   transition so the running position and P&L change at a single assignment
   site (see [apply_own_fill]). Deliberately phase-independent: fills arrive
   asynchronously on [on_event], so e.g. a buy fill can land after the tick
   that flipped [Accumulate -> Distribute] and must still be counted. *)
module Book = struct
  type t =
    { position : int (* Signed shares held; long while accumulating. *)
    ; cost_cents : int (* Running notional paid while buying. *)
    ; proceeds_cents : int (* Running notional taken while selling. *)
    }

  let empty = { position = 0; cost_cents = 0; proceeds_cents = 0 }

  let apply_fill t ~side ~qty ~notional_cents =
    let position = t.position + (Side.sign side * qty) in
    match side with
    | Side.Buy ->
      { t with position; cost_cents = t.cost_cents + notional_cents }
    | Sell ->
      { t with position; proceeds_cents = t.proceeds_cents + notional_cents }
  ;;

  let realized_pnl_cents t = t.proceeds_cents - t.cost_cents
end

module Config = struct
  type t =
    { target_symbol : Symbol.t
        (* The single symbol to manipulate. Concentrating every clip on one
           symbol is what moves its price; spreading across many would dilute
           the impact to nothing. *)
    ; pump_target_pct : Percent.t
        (* Flip from [Accumulate] to [Distribute] once the observed mid has
           risen this far above [anchor_cents]. The success trigger, derived
           purely from observed prices -- never the fundamental oracle, so
           the bot exits on the same information a real manipulator would
           have. *)
    ; clip_size : int
        (* Shares taken per tick. The push-rate lever: a bigger clip walks
           the book faster and moves price harder, but is more conspicuous. *)
    ; max_inventory : int
        (* Cap on the accumulated long. Not a flip trigger: it clamps
           per-tick buying so the position never runs away if the price won't
           rise. *)
    ; give_up_ticks : int
        (* If still accumulating after this many ticks (the price never
           reached [pump_target_pct]), flip to [Distribute] and unwind
           anyway. The honest "the scheme failed" path, so the bot never
           holds forever. *)
    ; aggression_offset_cents : int
        (* How far past the opposite touch each clip is priced, so it
           reliably crosses and trades rather than resting at the touch. *)
    ; entry_time_in_force : Time_in_force.t
        (* Time-in-force of every clip. [Ioc] keeps clips clean -- they trade
           what they can immediately and leave no resting exposure behind. *)
    ; generator : Client_order_id.Generator.t
      (* Three mutable cells, each a distinct concern: the strategy's state
         machine, the fill-driven accounting, and a market-data cache. *)
    ; mutable phase : Phase.t
    ; mutable book : Book.t
    ; mutable last_bbo : Bbo.t option
    (* Last BBO observed for [target_symbol]; the price reference every clip
       is priced off. *)
    }

  let create
    ~target_symbol
    ~pump_target_pct
    ~clip_size
    ~max_inventory
    ~give_up_ticks
    ~aggression_offset_cents
    ~entry_time_in_force
    =
    { target_symbol
    ; pump_target_pct
    ; clip_size
    ; max_inventory
    ; give_up_ticks
    ; aggression_offset_cents
    ; entry_time_in_force
    ; generator = Client_order_id.Generator.create ()
    ; phase = Awaiting_anchor
    ; book = Book.empty
    ; last_bbo = None
    }
  ;;

  module For_testing = struct
    let phase t = t.phase
    let position t = t.book.Book.position
    let realized_pnl_cents t = Book.realized_pnl_cents t.book
  end
end

let name = "Pump-and-dump"

(* Smallest amount by which a clip crosses past the opposite best price, so
   it is guaranteed to trade rather than sit at the touch. *)
let cross_cents = 1

(* Price a clip to cross the *opposite* best (so it trades immediately),
   pushed a random 0..[aggression_offset_cents] further past the touch. Falls
   back to the fundamental when we have not yet seen a BBO for that side of
   the book. *)
let clip_price (config : Config.t) context ~side rng =
  let opposite =
    let cached =
      let%bind.Option bbo = config.last_bbo in
      Bbo.price bbo (Side.flip side)
    in
    match cached with
    | Some price -> Price.to_int_cents price
    | None ->
      Price.to_int_cents (Context.fundamental context config.target_symbol)
  in
  let jitter =
    Splittable_random.int rng ~lo:0 ~hi:config.aggression_offset_cents
  in
  let cents =
    match side with
    | Side.Buy -> opposite + cross_cents + jitter
    | Sell -> opposite - cross_cents - jitter
  in
  Price.of_int_cents (Int.max 1 cents)
;;

(* Mid of a two-sided BBO in integer cents, or [None] if either side is
   empty. Anchors the scheme and measures how far price has moved -- all from
   observed market data, never the oracle. *)
let observed_mid_of_bbo bbo =
  let%bind.Option bid = Bbo.price bbo Side.Buy in
  let%map.Option ask = Bbo.price bbo Side.Sell in
  (Price.to_int_cents bid + Price.to_int_cents ask) / 2
;;

let observed_mid (config : Config.t) =
  let%bind.Option bbo = config.last_bbo in
  observed_mid_of_bbo bbo
;;

(* Send one marketable clip: a single order of [size] shares priced by
   {!clip_price} to cross the opposite touch so it trades immediately rather
   than resting. A buy lifts the offer during [Accumulate]; a sell hits the
   bid during [Distribute]. *)
let submit_clip (config : Config.t) context ~side ~size =
  let rng = Context.random context in
  let request : Order.Request.t =
    { client_order_id = Client_order_id.Generator.next config.generator
    ; symbol = config.target_symbol
    ; participant = Context.participant context
    ; side
    ; price = clip_price config context ~side rng
    ; size = Size.of_int size
    ; time_in_force = config.entry_time_in_force
    }
  in
  Deferred.ignore_m (Context.submit context request)
;;

(* Fold one of our own fills into the book. Only fills we are a party to
   move the books, and self-trade prevention means we are at most one side.
   The arithmetic itself is {!Book.apply_fill}. *)
let apply_own_fill context (config : Config.t) (fill : Fill.t) =
  let me = Context.participant context in
  let our_side =
    if Participant.equal fill.aggressor_participant me
    then Some fill.aggressor_side
    else if Participant.equal fill.resting_participant me
    then Some (Side.flip fill.aggressor_side)
    else None
  in
  match our_side with
  | None -> ()
  | Some side ->
    let qty = Size.to_int fill.size in
    let notional_cents = Price.to_int_cents fill.price * qty in
    config.book <- Book.apply_fill config.book ~side ~qty ~notional_cents
;;

let on_start (_config : Config.t) _context = Deferred.unit

(* One tick of the state machine. [Awaiting_anchor] does nothing -- the
   scheme starts only once a first two-sided BBO has anchored it (see
   [on_event]). [Accumulate] fires buy clips until the observed mid has
   risen [pump_target_pct] off the anchor (or the [give_up_ticks] budget
   runs out), then [Distribute] unwinds the inventory with sell clips until
   flat, then [Done]. *)
let on_tick (config : Config.t) context =
  match config.phase with
  | Awaiting_anchor | Done -> Deferred.unit
  | Accumulate { anchor_cents; ticks_in_phase } ->
    let ticks_in_phase = ticks_in_phase + 1 in
    let target_reached =
      match observed_mid config with
      | None -> false
      | Some mid ->
        let rise_cents = Float.of_int (mid - anchor_cents) in
        let threshold_cents =
          Percent.apply config.pump_target_pct (Float.of_int anchor_cents)
        in
        Float.( >= ) rise_cents threshold_cents
    in
    if target_reached || ticks_in_phase >= config.give_up_ticks
    then (
      config.phase <- Distribute;
      Deferred.unit)
    else (
      config.phase <- Accumulate { anchor_cents; ticks_in_phase };
      let room = config.max_inventory - config.book.position in
      let size = Int.min config.clip_size room in
      if size <= 0
      then Deferred.unit
      else submit_clip config context ~side:Side.Buy ~size)
  | Distribute ->
    if config.book.position <= 0
    then (
      config.phase <- Done;
      Deferred.unit)
    else (
      let size = Int.min config.clip_size config.book.position in
      submit_clip config context ~side:Side.Sell ~size)
;;

(* Cache the target symbol's BBO for clip pricing, and track our own fills
   so the book follows a real run. The first two-sided market we see also
   starts the scheme: its mid becomes the anchor and we leave
   [Awaiting_anchor] for [Accumulate]. *)
let on_event (config : Config.t) context (event : Exchange_event.t) =
  (match event with
   | Best_bid_offer_update { symbol; bbo } ->
     if Symbol.equal symbol config.target_symbol
     then (
       config.last_bbo <- Some bbo;
       match config.phase with
       | Awaiting_anchor ->
         (match observed_mid_of_bbo bbo with
          | Some mid ->
            config.phase
            <- Accumulate { anchor_cents = mid; ticks_in_phase = 0 }
          | None -> ())
       | Accumulate _ | Distribute | Done -> ())
   | Fill fill ->
     if Symbol.equal fill.symbol config.target_symbol
     then apply_own_fill context config fill
   | Order_accept _ | Order_cancel _ | Order_reject _ | Cancel_reject _
   | Trade_report _ ->
     ());
  Deferred.unit
;;
