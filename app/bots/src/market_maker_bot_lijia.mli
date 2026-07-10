(** A minimal market maker for scenario supporting cast: each tick it cancels
    its previous quotes and re-posts a symmetric ladder of resting bids and
    asks around the oracle's fundamental, keeping a fresh two-sided market
    (and a steady stream of [Best_bid_offer_update] events) alive. It is
    deliberately dumb — no inventory tracking, no skew. *)

open! Core
open! Async
open Jsip_types
open Jsip_bot_runtime

module Config : sig
  type t

  (** Build a market-maker config.

      - [symbol]: the symbol to quote.
      - [half_spread_cents]: cents from fair value to the innermost quote.
      - [size_per_level]: shares per quote.
      - [num_levels]: quotes per side, one cent further out each. *)
  val create
    :  symbol:Symbol_id.t
    -> half_spread_cents:int
    -> size_per_level:int
    -> num_levels:int
    -> t
end

val name : string
val on_start : Config.t -> Bot_runtime.Context.t -> unit Deferred.t
val on_tick : Config.t -> Bot_runtime.Context.t -> unit Deferred.t

val on_event
  :  Config.t
  -> Bot_runtime.Context.t
  -> Exchange_event.t
  -> unit Deferred.t
