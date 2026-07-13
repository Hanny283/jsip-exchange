open! Core
open! Jsip_types

type t =
  | Submit of Order.Request.t
  | Book of Symbol_id.t
  | Subscribe of Symbol_id.t
  | Cancel of Client_order_id.t

(** Parse one typed command line. [symbols] is the consumer's directory
    mirror: the symbol token is the human name, resolved to its id at parse
    time (name->id happens here; unknown names are parse errors). *)
val parse : symbols:Symbol_registry.t -> string -> t Or_error.t
