open! Core
open! Async
open Jsip_types

(** A noise trader: a stand-in for real-world buying and selling that carries
    no view on price (index rebalancing, retail flow, a liquidation). Each
    tick it picks a symbol, side, size, price, and time-in-force at random
    and submits one order, giving the matching engine activity for informed
    bots to react to. With probability [aggressiveness] the order crosses the
    opposite best (marketable); otherwise it rests near its own best. Prices
    come from a per-symbol BBO cache (kept from [Best_bid_offer_update]
    events), falling back to the oracle fundamental on an empty book. *)
module Config : sig
  type t

  (** Build a noise-trader config; the BBO cache starts empty.

      - [symbols]: symbols to trade, chosen uniformly.
      - [mean_size]: center of each order's randomized size.
      - [tick_chance]: probability a given tick sends any order, so a fast
        clock can still stay sparse.
      - [aggressiveness]: probability an order is marketable rather than
        resting away from the best.
      - [time_in_force_distribution]: distribution the time-in-force is drawn
        from (a weighted entry per {!Time_in_force.t}). *)
  val create
    :  symbols:Symbol_id.t list
    -> mean_size:int
    -> tick_chance:Percent.t
    -> aggressiveness:Percent.t
    -> time_in_force_distribution:Time_in_force.t Bot_random.distribution
    -> t
end

include Jsip_bot_runtime.Bot_runtime.Bot with module Config := Config
