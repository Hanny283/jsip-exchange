(** Text protocol for communicating with the exchange.

    This module defines how exchange events are formatted for display. On a
    production exchange, this would be a binary protocol like FIX for
    performance and interoperability. We use a simple human-readable text
    format for ease of debugging and interactive use.

    Command {e parsing} lives in {!Exchange_command}; the grammar is
    {v
    BUY  <client_order_id> <symbol> <size> <price> [<time_in_force>]
    SELL <client_order_id> <symbol> <size> <price> [<time_in_force>]
    v}
    Time-in-force defaults to DAY if omitted. Commands carry no participant:
    identity comes from the login handshake, and the server stamps it onto
    each submission. *)

open! Core
open Jsip_types

(** Format an exchange event as a single line of human-readable text. *)
val format_event : Exchange_event.t -> string

(** Format a list of events, one per line. *)
val format_events : Exchange_event.t list -> string
