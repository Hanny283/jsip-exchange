(** The RPC a browser dashboard uses to catch up on recent
    {!Jsip_types.Exchange_stats} snapshots.

    The dashboard server tails the exchange's [exchange-stats] pipe RPC into
    a bounded in-memory buffer of recent snapshots. Browser clients poll this
    plain request/response RPC (over a websocket) about once a second,
    passing the sequence number of the newest snapshot they have already
    seen; the server replies with every buffered snapshot newer than that
    cursor. Polling with a cursor keeps each response small after the first
    one, and lets a client that reconnects late catch up from whatever the
    server still has buffered.

    A client's polling loop looks like:

    {[
      (* First poll: no cursor yet, ask for everything buffered. *)
      let query = { Recent_samples.Query.after_seq = None } in
      (* Later polls: only ask for snapshots newer than the cursor. *)
      let query = { Recent_samples.Query.after_seq = Some 42 } in
    ]}

    This module is the dashboard-side counterpart of
    [lib/gateway/src/rpc_protocol.ml]: the gateway defines the RPCs the
    exchange serves, this one defines the RPC the dashboard server serves.
    Like {!Jsip_types.Exchange_stats}, it depends only on [Core],
    [Async_rpc_kernel], and [Jsip_types], so it links into browser clients
    via js_of_ocaml. *)

open! Core
open Async_rpc_kernel
open Jsip_types

(** What the client asks for: snapshots it has not seen yet. *)
module Query : sig
  type t =
    { after_seq : int option
    (** The [seq] of the newest snapshot the client already holds. [None]
        means "send everything you have buffered" — the right first query for
        a client with no history. *)
    }
  [@@deriving bin_io, sexp, equal]
end

(** What the server sends back: the buffered snapshots newer than the
    client's cursor, plus the newest buffered sequence number. *)
module Response : sig
  type t =
    { samples : Exchange_stats.t list
    (** Snapshots with [seq] strictly greater than the query's [after_seq],
        in ascending [seq] order. Bounded by the server's buffer capacity, so
        a client that has been away a long time only receives the recent
        window, not full history. *)
    ; latest_seq : int option
    (** [seq] of the newest buffered snapshot, or [None] if the buffer is
        empty. A [latest_seq] below the client's cursor means the server (or
        the exchange behind it) restarted and snapshot numbering began again
        — the client should reset its window rather than wait for the old
        cursor to be exceeded. *)
    }
  [@@deriving bin_io, sexp_of]
end

(** The polling RPC itself: ["dashboard-recent-samples"], version 1. The
    dashboard server implements it against its snapshot buffer; browser
    clients dispatch it once a second. Its wire shape is pinned by the expect
    test in [app/dashboard/test/test_protocol_shapes.ml]. *)
val rpc : (Query.t, Response.t) Rpc.Rpc.t
