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

(** [run ~host ~port ~on_connect ~on_sample] connects to the exchange at
    [host:port], subscribes to the exchange-stats pipe RPC, and calls
    [on_sample] on each snapshot as it arrives. When the connection cannot be
    established, the subscription fails, or the pipe closes (e.g. the
    exchange restarts), it logs the failure via [Log.Global], waits one
    second, and reconnects — so a dashboard started before the exchange, or
    one that outlives an exchange restart, recovers by itself.

    [on_connect] fires once each time a fresh stats subscription is
    established, just before the first snapshot of that run. Because every
    exchange run numbers its snapshots from 1, the caller uses this to clear
    any buffer holding a previous run's samples: mixing two runs' [seq]
    ranges in one buffer would freeze the dashboard (the old run's higher
    seqs shadow the new run's).

    The returned deferred never becomes determined; run it under
    [don't_wait_for]:

    {[
      don't_wait_for
        (Exchange_feed.run
           ~host
           ~port
           ~on_connect:(fun () -> ...)
           ~on_sample:(fun sample -> ...))
    ]} *)
val run
  :  host:string
  -> port:int
  -> on_connect:(unit -> unit)
  -> on_sample:(Exchange_stats.t -> unit)
  -> unit Deferred.t
