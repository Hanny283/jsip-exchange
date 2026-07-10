(** Exchange server for production use and testing.

    Bundles the matching engine, market data bus, and RPC implementations
    into a single server that can be started on any port. Used by the server
    binary, the market maker binary, and integration tests. *)

open! Core
open! Async
open Jsip_types

type t

(** Start a server on the given port with the given symbols. Returns the
    server handle and the port it is actually listening on (useful when you
    pass port 0 to get an OS-assigned port).

    [stats_interval] (default one second) is how often the server samples
    itself and broadcasts an [Exchange_stats.t] snapshot to subscribers of
    [Rpc_protocol.exchange_stats_rpc]. Tests that need deterministic
    snapshots pass a huge interval so the timer never fires after the
    immediate startup tick, then force snapshots via
    {!For_testing.publish_stats_snapshot}.

    [fundamental] supplies each snapshot's per-symbol fundamental ("fair")
    price, for a dashboard to plot against the observed market price. It
    defaults to [fun _ -> None] — the bare exchange knows no fundamental — so
    only a scenario runner (which owns the price oracle) passes it. *)
val start
  :  symbols:Symbol.t list
  -> port:int
  -> ?stats_interval:Time_ns.Span.t
  -> ?fundamental:(Symbol_id.t -> Price.t option)
  -> unit
  -> t Deferred.t

(** The port the server is listening on. *)
val port : t -> int

(** Stop the server and close all connections. *)
val close : t -> unit Deferred.t

(** Wait until the server's TCP listener is closed. *)
val close_finished : t -> unit Deferred.t

module For_testing : sig
  (** Assemble and broadcast one stats snapshot immediately, exactly as the
      periodic timer would. Lets tests pin snapshot contents
      deterministically: start the server with a huge [stats_interval] and
      call this at known points instead of waiting for the clock. *)
  val publish_stats_snapshot : t -> unit
end
