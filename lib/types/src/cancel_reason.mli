(** Why an order was cancelled.

    A production exchange would have more granular cancellation reasons --
    risk limit breaches, trading halts, etc. *)

open! Core

type t =
  | Participant_requested
  (** The participant explicitly asked to cancel their order. *)
  | Ioc_remainder
  (** The unfilled portion of an IOC order was automatically cancelled. *)
  | End_of_day (** Day orders are cancelled when the trading session ends. *)
  | Self_trade_prevention
  (** The incoming order would have matched against a resting order from the
      same participant, so the exchange cancelled it instead of trading. *)
[@@deriving sexp, bin_io, compare, equal, hash, string]
