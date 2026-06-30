(** A simple market-making bot.

    A market maker provides liquidity by continuously quoting both a bid
    (buy) and an ask (sell) price. They profit from the spread between the
    two prices, but take risk if the market moves against their inventory.

    This bot places a fixed set of resting orders on both sides of the book
    around a configured "fair value" price. It does not dynamically adjust
    its quotes in response to fills -- that is left as an extension. *)

open! Core
open! Async
open Jsip_types

(** Configuration for the market maker. *)
module Config : sig
  type t =
    { participant : Participant.t
    ; symbol : Symbol.t
    ; fair_value_cents : int
    (** The market maker's estimate of the true price, in cents. *)
    ; half_spread_cents : int
    (** Half-spread in cents. The bot will bid at [fair_value - half_spread]
        and offer at [fair_value + half_spread]. *)
    ; size_per_level : int (** Number of shares at each price level. *)
    ; num_levels : int
    (** Number of price levels on each side. The bot places orders at
        [fair_value +/- spread], [fair_value +/- (spread + tick)], etc. *)
    ; inventory_skew_cents_per_share : int
    }
  [@@deriving sexp_of]
end

(** Submit the market maker's initial set of resting orders over the given
    open [Rpc.Connection.t]. The connection must already be logged in as
    [config.participant]. [submit_order_rpc] is one-way, so this function
    only returns success/failure of the submission attempt; the actual
    matching-engine response (acceptance, fills, rejection) arrives on the
    participant's session feed. *)
val seed_book : Config.t -> Rpc.Connection.t -> unit Deferred.t

(** Returns a never-determined `Deferred.t` (i.e., `Deferred.never`).
    Internally it seeds the initial ladder, subscribes to the session feed,
    and reacts to fills by cancelling resting orders and re-posting. *)

val run : Config.t -> Rpc.Connection.t -> unit Deferred.t

(** The per-connection machinery behind [run], exposed so the inventory and
    outstanding-order bookkeeping can be unit-tested without a live exchange
    connection. [submit] and [cancel] are the effectful hooks the strategy uses
    to talk to the exchange; [run] wires them to the RPCs, while tests pass
    recording closures.

    Returns, in order:
    - the outstanding-order table (client order id -> size still working),
    - the per-symbol inventory table (filled buys add, filled sells subtract),
    - [post], which quotes a fresh ladder skewed by the current inventory, and
    - the session-feed event handler. *)
val make
  :  Config.t
  -> submit:(Order.Request.t -> unit Deferred.t)
  -> cancel:(Client_order_id.t -> unit Deferred.t)
  -> int Client_order_id.Table.t
     * int Symbol.Table.t
     * (unit -> unit Deferred.t)
     * (Exchange_event.t -> unit)
