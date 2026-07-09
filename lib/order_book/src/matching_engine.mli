(** The matching engine: receives order requests, manages order books, and
    produces exchange events.

    The engine is the heart of the exchange. It assigns order IDs, determines
    which orders can trade against each other, executes fills, and manages
    the lifecycle of resting orders. *)

open! Core
open Jsip_types

type t [@@deriving sexp_of]

(** Create a matching engine for the given symbols. Each symbol gets its own
    order book. *)
val create : Symbol.t list -> t

(** {2 Order submission} *)

(** Submit a new order request on behalf of [participant] — the identity the
    gateway authenticated at login, not anything the client wrote in the
    request. Returns the list of exchange events produced: an acceptance or
    rejection, followed by any fills, and possibly a cancellation of unfilled
    remainder (for IOC orders, or when the order would have self-traded).

    Self-trade prevention: an order never fills against a resting order from
    the same participant. If the next candidate match belongs to the
    aggressor, matching stops and the aggressor's remainder is cancelled with
    {!Cancel_reason.Self_trade_prevention}; the resting order stays on the
    book. Fills already executed against other participants stand.

    The request's [client_order_id] must be unused by its participant; a
    repeat id produces an [Order_reject] instead of an acceptance. Accepted
    ids stay reserved permanently (even after the order fills or cancels), so
    a client can never reuse one.

    The event list is always non-empty (at minimum an acceptance or
    rejection). *)
val submit
  :  t
  -> Order.Request.t
  -> participant:Participant.t
  -> Exchange_event.t list

(** {2 Cancellation} *)

(** Cancel the order identified by [(participant, client_order_id)] — the
    pair the client used to submit it. A still-resting order is removed from
    its book and reported with [Order_cancel] (followed by a
    [Best_bid_offer_update] if the best price on that side moved). An id that
    was never used, or whose order has already left the book (filled or
    previously cancelled), yields a single [Cancel_reject]. *)
val cancel
  :  t
  -> participant:Participant.t
  -> client_order_id:Client_order_id.t
  -> Exchange_event.t list

(** {2 Queries} *)

(** The order book for a given symbol, or [None] if the symbol is not traded
    on this engine. *)
val book : t -> Symbol.t -> Order_book.t option
