(** A server-local integer handle for a participant.

    {!Jsip_types.Participant.t} stays the human name everywhere a client can
    see — the login RPC, exchange events, stats snapshots. This type is that
    name interned to a small dense int at login, so the gateway's own tables
    (sessions, per-participant counters) can key by int instead of hashing
    the name string on every touch.

    It never crosses the wire, by construction rather than by discipline: it
    derives no [bin_io], so embedding one in an RPC type is a compile error.
    There is also no [of_int] — the only mint is {!Registry.intern} — so any
    id you hold came from the registry and resolves back to a name with
    {!Registry.name}. *)

open! Core
open Jsip_types

type t = private int [@@deriving compare, equal, hash, sexp_of]

include Comparable.S_plain with type t := t
include Hashable.S_plain with type t := t

(** The server-global name<->id map.

    Additive: the k-th distinct name ever interned gets id [k], and an id
    stays valid for the whole run, so a participant keeps the same id across
    reconnects. This is deliberately a different structure with a different
    lifetime from the dispatcher's session table, which tracks who is
    connected {e now} and is pruned on disconnect. *)
module Registry : sig
  type id := t
  type t

  val create : unit -> t

  (** [intern t name] is the id for [name], interning it on first sight.
      Idempotent: the same name always yields the same id. *)
  val intern : t -> Participant.t -> id

  (** [find t name] is the id [name] was interned under, or [None] if this
      name has never logged in (and so cannot have a session). *)
  val find : t -> Participant.t -> id option

  (** [name t id] is the name behind an id minted by this registry. Total for
      any id this registry issued; raises only on an id from a {e different}
      registry, which the private type makes hard to do by accident. *)
  val name : t -> id -> Participant.t
end
