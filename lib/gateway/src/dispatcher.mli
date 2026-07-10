(** Central event-routing component for the gateway.

    Owns subscription registries:

    - **Market-data subscribers**, one bag per traded [Symbol_id.t] (a dense
      array — per-event routing is an index). Each subscriber gets a pipe of
      [Best_bid_offer_update] and [Trade_report] events for the symbol they
      asked about. This is the public market-data feed.

    - **Audit subscribers**, an unfiltered firehose of every event the
      matching engine produces. Intended for the exchange operator's monitor;
      not appropriate to expose to ordinary clients.

    [dispatch] is the single place that decides "for each event, who gets
    it". *)

open! Core
open! Async
open Jsip_types

type t

(** Create a dispatcher.

    Events whose audience is a single participant (order-lifecycle responses
    and [Fill] events) are written to that participant's [Session] outbound
    pipe, which the client drains via [session_feed_rpc]. Register and
    unregister sessions with [set_up_session] / [clean_up_session].

    [registry] is the server-global name<->id map shared with the stats
    pipeline. Internally the session table is keyed by {!Participant_id.t};
    [set_up_session] interns the name (so login is where a name becomes an
    id), and routing resolves each event's participant name back through
    [registry]. The dispatcher's own API still speaks names — the id never
    leaves the server.

    [num_symbols] sizes the per-symbol market-data routing array: the
    dispatcher serves symbol ids [0 .. num_symbols - 1], matching the
    engine's trading set. *)
val create : registry:Participant_id.Registry.t -> num_symbols:int -> t

(** The session currently registered for [participant], if any. Used by the
    login handler to detect a name that's already in use and to recover the
    [Session.t] that [set_up_session] just created. *)
val find_session : t -> Participant.t -> Session.t option

(** Subscribe to public market data for one or more [symbols]. The same pipe
    receives events for every requested symbol; the dispatcher avoids
    duplicates so a subscriber listed against multiple symbols only sees each
    event once. The pipe is removed from the dispatcher when its reader is
    closed. Every id must be in [0 .. num_symbols - 1] — the market-data RPC
    handler validates before subscribing; an out-of-range id here raises. *)
val subscribe_market_data
  :  t
  -> Symbol_id.t list
  -> Exchange_event.t Pipe.Reader.t

(** Subscribe to the full unfiltered event firehose. Intended for the monitor
    / admin tools. *)
val subscribe_audit : t -> Exchange_event.t Pipe.Reader.t

(** Route each event to every interested subscriber:

    - Every event is pushed to every audit subscriber.
    - [Best_bid_offer_update] and [Trade_report] are pushed to the
      market-data subscribers that asked for the event's symbol.
    - [Order_accept], [Order_cancel], [Order_reject], and [Cancel_reject] are
      pushed to the session of the order's owning participant (if logged in).
    - [Fill] is pushed to both the aggressor's and the resting party's
      session (if either is logged in).

    Each session lookup is O(1) and independent of subscriber count. *)
val dispatch : t -> Exchange_event.t list -> unit

val clean_up_session : t -> Session.t -> unit Deferred.t
val set_up_session : t -> Participant.t -> unit Deferred.t

(** {2 Introspection}

    Point-in-time occupancy of every subscriber pipe the dispatcher owns.
    Because events are written with [Pipe.write_without_pushback_if_open], a
    subscriber that stops draining accumulates buffered events without bound
    — these accessors let a stats sampler observe that buildup. Each call is
    a fresh snapshot; lengths change as events are dispatched and subscribers
    drain. *)

(** [Pipe.length] of each audit subscriber's pipe, in bag order (one entry
    per subscriber; the order is arbitrary but stable between calls as long
    as no subscriber joins or leaves). *)
val audit_pipe_lengths : t -> int list

(** [Pipe.length] of each market-data subscriber's pipe, grouped by symbol.
    Rows are in id order and only ids with a live subscriber appear; within a
    symbol, entries are in bag order. A subscriber registered for several
    symbols (via [subscribe_market_data]) shares one pipe across all of them,
    so it appears under each of its symbols with the same (total) length. *)
val market_data_pipe_lengths : t -> (Symbol_id.t * int list) list

(** [Pipe.length] of each logged-in participant's session feed pipe, sorted
    by participant. *)
val session_pipe_lengths : t -> (Participant.t * int) list

module For_testing : sig
  val audit_subscriber_count : t -> int
end
