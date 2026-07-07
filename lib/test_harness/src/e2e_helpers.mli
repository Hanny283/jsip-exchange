(** Shared helpers for end-to-end tests that use a real server and RPC
    clients. *)

open! Core
open! Async
open Jsip_types
open Jsip_gateway

(** Start a server on an OS-assigned port, run [f], then shut down.

    [stats_interval] is passed through to {!Exchange_server.start}. Tests
    that pin stats-snapshot contents pass a huge interval, so that only the
    immediate startup tick fires on its own, and force further snapshots with
    {!Exchange_server.For_testing.publish_stats_snapshot}. *)
val with_server
  :  symbols:Symbol.t list
  -> ?stats_interval:Time_ns.Span.t
  -> (server:Exchange_server.t -> port:int -> 'a Deferred.t)
  -> 'a Deferred.t

(** A test client: an open RPC connection to the server. A future revision
    (once the session-feed RPC and login flow exist) will extend this with a
    buffered session feed so [rpc_submit] can return the events produced by
    the just-submitted request. *)
type client

(** Connect a client to [port]. The [participant] argument is accepted f with
    the login and dispatches a session feed to print every event received
    with a participant tag prefix *)
val connect_as : port:int -> Participant.t -> client Deferred.t

(** Open a raw RPC connection to [port] without logging in or subscribing to
    a session feed. Useful for tests that exercise the pre-login error paths
    (submitting or cancelling before login) or that need a second connection
    to attempt a duplicate login by dispatching [login_rpc] directly. *)
val connect_raw : port:int -> Rpc.Connection.t Deferred.t

(** The raw RPC connection, useful for tests that exercise unusual RPC paths
    (audit log subscriptions, second clients on the same connection, etc.). *)
val connection : client -> Rpc.Connection.t

(** Submit an order via RPC. The RPC is one-way: this returns once the server
    has enqueued the request. Participant-targeted events (acceptance, fills,
    rejection) are currently printed on the server's stdout via the
    dispatcher's session stub. *)
val rpc_submit : client -> Order.Request.t -> unit Deferred.t

(** Query the book via RPC. *)
val rpc_book : client -> Symbol.t -> Book.t option Deferred.t

(** Subscribe to the server's periodic {!Exchange_stats.t} snapshots via
    {!Rpc_protocol.exchange_stats_rpc}. Raises (failing the test) if the
    dispatch is rejected. *)
val subscribe_stats : client -> Exchange_stats.t Pipe.Reader.t Deferred.t
