(** A pathological "quote-stuffing" / layering bot.

    On every tick {!on_tick} reads the latest cached BBO for each configured
    symbol and floods the book with [orders_per_burst] tiny resting Day
    orders on {e each} side, priced one tick inside the opposite quote:

    - buys at [best_ask - 1 cent]
    - sells at [best_bid + 1 cent]

    Each order therefore rests exactly one tick short of being marketable — a
    buy only trades at [price >= best_ask] (see
    {!Jsip_types.Price.is_marketable}) — so nothing ever fills. The orders
    just pile up: this bot never cancels.

    The point is to stress the exchange, not to make money. Every resting
    order is an O(n) burden on the order book's list scans, and every
    distinct [client_order_id] permanently occupies a slot in the matching
    engine's per-participant table. Pointed at a live market through
    {!Jsip_scenario_runner}, it collapses the spread to a single tick and
    grows both memory and match latency without bound.

    It implements {!Jsip_bot_runtime.Bot_runtime.Bot}, so it drops into a
    [Bot_spec.t] like any other bot. It must be registered as a market-data
    consumer so {!on_event} sees the [Best_bid_offer_update]s it pegs to;
    with no cached BBO for a symbol it does nothing. Contrast with
    {!Jsip_bots.Static_quoter}, the well-behaved liquidity source that seeds
    the BBO this bot preys on. *)

open! Core
open! Async
open Jsip_types
module Bot_runtime = Jsip_bot_runtime.Bot_runtime

module Config : sig
  (** Tunables plus the bot's internal mutable state (the per-symbol BBO
      cache and a monotonic client-order-id counter). Build one with
      {!create}; a scenario supplies only the tunables. *)
  type t

  (** [create ~symbols ~orders_per_burst ~order_size] floods [symbols],
      sending [orders_per_burst] orders per side on every tick, each of
      [order_size] shares. The BBO cache starts empty and the id counter at
      zero. *)
  val create
    :  symbols:Symbol_id.t list
    -> orders_per_burst:int
    -> order_size:Size.t
    -> t
end

include Bot_runtime.Bot with module Config := Config
