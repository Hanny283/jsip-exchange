(** A dense integer id for a symbol — the wire representation.

    The server's [main] owns the authoritative assignment: the i-th symbol
    the exchange trades gets id [i]. Every payload that crosses the wire
    ({!Order.Request}, {!Book}, {!Fill}, the exchange events, the book-query
    and market-data queries) carries this id; the human-readable name
    ({!Symbol.t}) appears only in the symbol directory and in consumer-side
    rendering.

    Like every type in this library, this is pure data: [to_string] prints
    the int, and no name registry is threaded in here. The type guards
    {e shape}, not membership — {!of_int} rejects negatives, but whether an
    id denotes a symbol the exchange actually trades is the server's bounds
    check against its symbol set. [bin_io] decoding performs no validation at
    all, so the server must never index by an unchecked id. *)

open! Core

type t = private int [@@deriving sexp, bin_io, compare, equal, hash, string]

include Comparable.S with type t := t
include Hashable.S with type t := t

(** Raises on a negative int. Public — unlike {!Order_id}, ids legitimately
    originate outside the engine: directory mirrors, positional assignment in
    scenarios and tests, and humans typing raw ids. The textual entry points
    ([of_string], [t_of_sexp]) validate through here too. *)
val of_int : int -> t

val to_int : t -> int
