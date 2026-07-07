(** The dashboard server's connection to the exchange: subscribes to
    {!Jsip_gateway.Rpc_protocol.exchange_stats_rpc} and hands every snapshot
    to a callback, reconnecting forever.

    The feed is deliberately fire-and-forget: the caller supplies an
    [on_sample] callback (in practice one that swaps a {!Sample_buffer} ref,
    see [app/dashboard/server/main.ml]) and never hears about connection
    trouble directly — failures are logged and retried, and the dashboard
    simply serves its last buffered snapshots meanwhile. *)

open! Core
open! Async
open Jsip_types

(** [run ~host ~port ~on_sample] connects to the exchange at [host:port],
    subscribes to the exchange-stats pipe RPC, and calls [on_sample] on each
    snapshot as it arrives. When the connection cannot be established, the
    subscription fails, or the pipe closes (e.g. the exchange restarts), it
    logs the failure via [Log.Global], waits one second, and reconnects — so
    a dashboard started before the exchange, or one that outlives an exchange
    restart, recovers by itself.

    The returned deferred never becomes determined; run it under
    [don't_wait_for]:

    {[
      don't_wait_for
        (Exchange_feed.run ~host ~port ~on_sample:(fun sample -> ...))
    ]} *)
val run
  :  host:string
  -> port:int
  -> on_sample:(Exchange_stats.t -> unit)
  -> unit Deferred.t
