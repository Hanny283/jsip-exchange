(** Assembles {!Jsip_types.Exchange_stats.t} snapshots and broadcasts them to
    subscribers of the exchange-stats RPC.

    One publisher lives inside the exchange server. On every {!tick} it
    gathers the pieces of a snapshot from the components it was created with:
    GC numbers from the runtime, interval metrics (latencies, per-participant
    command counts, loop cadence) flushed from the {!Stats_collector}, pipe
    occupancies from the {!Dispatcher} plus its own subscriber pipes and the
    server's request queue, and a whole-book depth scan via
    {!Jsip_order_book.Matching_engine.book} and
    {!Jsip_order_book.Order_book.iter_orders}. The finished snapshot goes to
    every live subscriber.

    Subscription management mirrors {!Dispatcher.subscribe_audit}: the
    publisher owns a bag of writer pipes, drops a subscriber when its reader
    closes, and writes snapshots with [Pipe.write_without_pushback_if_open].
    As with the audit feed, that means a subscriber that stops draining
    buffers snapshots without bound — acceptable here because snapshots are
    small and arrive once per interval, and their pipes are themselves
    reported in each snapshot's [stats_subscribers] occupancy, so the buildup
    is visible.

    Typical wiring inside the server:

    {[
      let publisher =
        Stats_publisher.create
          ~collector
          ~dispatcher
          ~engine
          ~symbols
          ~request_queue_length:(fun () -> Pipe.length request_writer)
      in
      Stats_publisher.start
        publisher
        ~interval:Time_ns.Span.second
        ~stop:(Tcp.Server.close_finished tcp_server)
    ]} *)

open! Core
open! Async
open Jsip_types
open Jsip_order_book

type t

(** [create ~collector ~dispatcher ~engine ~symbols ~request_queue_length] is
    a publisher with no subscribers that has produced no snapshots (the first
    {!tick} emits [seq = 1]).

    - [collector] is flushed on every tick; the publisher must be the only
      flusher, since flushing resets the interval metrics.
    - [dispatcher] supplies subscriber-pipe occupancies via its introspection
      accessors ({!Dispatcher.audit_pipe_lengths} etc.).
    - [engine] and [symbols] drive the per-symbol book scan; symbols the
      engine does not trade are skipped.
    - [request_queue_length] reports the matching loop's inbound queue
      occupancy. It is a closure because the server owns that pipe; called
      once per tick. *)
val create
  :  collector:Stats_collector.t
  -> dispatcher:Dispatcher.t
  -> engine:Matching_engine.t
  -> symbols:Symbol.t list
  -> request_queue_length:(unit -> int)
  -> t

(** [subscribe t] returns a pipe that receives every snapshot produced after
    this call. Closing the reader unregisters the subscriber. See the module
    doc for the no-pushback caveat. *)
val subscribe : t -> Exchange_stats.t Pipe.Reader.t

(** [tick t] assembles one snapshot right now and broadcasts it to all
    subscribers. This flushes the {!Stats_collector} (resetting its interval
    metrics) and calls [Gc.stat ()], which walks the entire major heap — so
    keep ticks to once per sampling interval. Exposed separately from
    {!start} so tests can force snapshots deterministically. *)
val tick : t -> unit

(** [start t ~interval ~stop] ticks [t] every [interval] until [stop] becomes
    determined (via [Clock_ns.every]). The first tick fires immediately, so
    subscribers see [seq = 1] at startup rather than one interval later. *)
val start : t -> interval:Time_ns.Span.t -> stop:unit Deferred.t -> unit
