(** Per-participant, per-symbol profit-and-loss tracking.

    A {!t} is an accumulator: you fold the exchange's fills and trade reports
    into it and ask for a {!summary} whenever you want a snapshot.

    For each (participant, symbol) pair we track three numbers:
    - [inventory]: signed share count (positive = long, negative = short);
    - the running {e cost basis} of the open position, from which the average
      entry price is derived;
    - [realized] cash, accumulated as positions are closed.

    P&L has two halves:
    - {b Realized} P&L is cash locked in by closing (or reducing) a position:
      the difference between what you paid to open and what you got to close.
    - {b Unrealized} P&L marks the still-open position to a reference price:
      [inventory * (reference_price - average_entry_price)]. The reference
      price comes from the most recent public trade print, fed in via
      {!apply_trade_report}.

    Example:
    {[
      let pnl =
        Pnl.empty
        |> fun t -> Pnl.apply_fill t fill1
        |> fun t -> Pnl.apply_fill t fill2
        |> fun t -> Pnl.apply_trade_report t last_print
      in
      Pnl.summary pnl alice
    ]}

    Fills come from {!Jsip_types.Fill}; trade reports arrive as the
    [Trade_report] variant of {!Jsip_types.Exchange_event}. *)

open! Core
open Jsip_types

type t

(** A tracker with no positions and no reference prices. *)
val empty : t

(** Fold a fill into the tracker. A single fill has {e two} sides — the
    aggressor and the resting participant — so this updates {e both} of their
    positions, in opposite directions, at the fill price. *)
val apply_fill : t -> Fill.t -> t

(** Refresh the reference price used to mark open positions. Only the
    [Trade_report] variant carries new information; every other event is
    ignored and returns the tracker unchanged. *)
val apply_trade_report : t -> Exchange_event.t -> t

(** A point-in-time P&L snapshot for one participant. *)
module Summary : sig
  (** One symbol's line in a {!t}. *)
  module Per_symbol : sig
    type t =
      { symbol : Symbol.t
      ; inventory : int (** Signed shares: positive long, negative short. *)
      ; average_entry : Price.t option
        (** Average price the open position was entered at, or [None] when
            flat. *)
      ; reference_price : Price.t option
        (** Latest trade-print price for this symbol, or [None] if none has
            been seen. *)
      ; realized_cents : int
      ; unrealized_cents : int
      }
    [@@deriving sexp_of]
  end

  type t =
    { per_symbol : Per_symbol.t list
    ; total_realized_cents : int
    ; total_unrealized_cents : int
    }
  [@@deriving sexp_of]
end

(** A per-symbol P&L breakdown for [participant], plus the totals across all
    symbols. Symbols the participant has never traded do not appear. *)
val summary : t -> Participant.t -> Summary.t
