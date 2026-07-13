(** A read-only snapshot of an order book.

    Contains the symbol, all resting price levels on each side (aggregated by
    price), and the BBO. *)

open! Core

type t =
  { symbol : Symbol_id.t
  ; bids : Level.t list
  ; asks : Level.t list
  ; bbo : Bbo.t
  }
[@@deriving sexp, bin_io]

val to_string : t -> string

(** As {!to_string} with the header rendered from [symbol] — lets a consumer
    holding a name directory print the human name without this pure-data
    library knowing about directories. *)
val to_string_with_symbol : t -> symbol:string -> string
