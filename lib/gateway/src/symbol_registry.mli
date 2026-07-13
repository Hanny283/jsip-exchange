(** The symbol name<->id mapping.

    The server's [main] builds the authority from its symbol list with
    {!of_symbols} — the i-th symbol gets id [i] — and hands it to
    [Exchange_server.start], which serves it read-only over the
    symbol-directory RPC. Clients and the monitor fetch that directory once
    at connect, rebuild a mirror with {!of_directory}, and use it in both
    directions: name->id when parsing typed commands ([Exchange_command]),
    id->name when rendering events and books ([Protocol.format_event]).

    Fixed for the run — contrast {!Participant_id.Registry}, which grows at
    every first login. Ids are dense [0 .. num_symbols - 1], matching the
    engine's books array. *)

open! Core
open Jsip_types

type t

(** Authority: symbol [i] of the list gets id [i]. Raises on a duplicate
    name. *)
val of_symbols : Symbol.t list -> t

(** Mirror: rebuild from a fetched directory. Errors unless the ids are
    exactly [0 .. n - 1] with distinct names — a malformed directory is a
    server bug worth failing at connect, not at first lookup. *)
val of_directory : (Symbol.t * Symbol_id.t) list -> t Or_error.t

(** The [(name, id)] pairs in id order — the directory RPC response. *)
val to_directory : t -> (Symbol.t * Symbol_id.t) list

val num_symbols : t -> int

(** [id t name] is the id [name] trades under, or [None] for a name this
    exchange does not trade. *)
val id : t -> Symbol.t -> Symbol_id.t option

(** [name t id] is the name behind [id], or [None] for an out-of-range id. *)
val name : t -> Symbol_id.t -> Symbol.t option
