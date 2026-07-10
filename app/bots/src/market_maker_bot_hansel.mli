open! Core
open! Async
open Jsip_types

(** A dynamic, multi-symbol market maker: for each symbol it quotes a ladder
    of bids and asks around the oracle's fundamental, skews it by inventory,
    and re-quotes as it fills. It adapts its half-spread toward the observed
    market and stands aside when the spread blows out past [max_spread_cents]
    (e.g. a whale swept a side of the book). *)
module Config : sig
  type t

  (** Build a market-maker config. Per-symbol state starts empty and evolves
      as events arrive; fair value is read from the oracle, not configured.

      - [symbols]: symbols to quote.
      - [size_per_level]: shares per quote.
      - [num_levels]: quotes posted per side, one cent apart.
      - [inventory_skew_cents_per_share]: cents the ladder shifts per share
        of inventory, to lean against the position.
      - [half_spread_cents]: starting half-spread; adapts toward the observed
        market, floored at [min_half_spread_cents].
      - [min_half_spread_cents]: floor on the half-spread.
      - [max_spread_cents]: whale tolerance — stop quoting a symbol whose
        market spread exceeds this until it recovers. *)
  val create
    :  symbols:Symbol_id.t list
    -> size_per_level:int
    -> num_levels:int
    -> inventory_skew_cents_per_share:int
    -> half_spread_cents:int
    -> min_half_spread_cents:int
    -> max_spread_cents:int
    -> t
end

include Jsip_bot_runtime.Bot_runtime.Bot with module Config := Config
