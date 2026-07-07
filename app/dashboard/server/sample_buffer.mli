(** A bounded, immutable buffer of the most recent
    {!Jsip_types.Exchange_stats} snapshots.

    The dashboard server drains the exchange's stats pipe into one of these,
    keeping only the newest [capacity] snapshots, and answers
    {!Jsip_dashboard_protocol.Recent_samples} queries from it. Values are
    immutable: {!add} returns a new buffer, so the server holds a [t ref] and
    swaps it on every incoming sample (see [app/dashboard/server/main.ml]):

    {[
      let buffer = ref (Sample_buffer.create ~capacity:300) in
      let on_sample sample = buffer := Sample_buffer.add !buffer sample
    ]}

    {!Exchange_feed} produces the samples; {!Web_server} calls {!response} to
    answer each browser poll. *)

open! Core
open! Async
open Jsip_types

type t [@@deriving sexp_of]

(** [create ~capacity] is an empty buffer that holds at most [capacity]
    snapshots. Raises if [capacity <= 0]. *)
val create : capacity:int -> t

(** [add t sample] appends [sample] as the newest snapshot, dropping the
    oldest one if the buffer is already at capacity. Samples are expected in
    ascending [seq] order — the exchange streams them that way. *)
val add : t -> Exchange_stats.t -> t

(** [latest_seq t] is the [seq] of the newest buffered snapshot, or [None] if
    the buffer is empty. *)
val latest_seq : t -> int option

(** [samples_after t ~after_seq] is every buffered snapshot with [seq]
    strictly greater than [after_seq], oldest first. The whole buffer is
    returned when [after_seq] is [None] (the client has no history yet), when
    the cursor lies below everything buffered (the client fell more than a
    buffer's worth behind), or when it exceeds [latest_seq t] (the exchange
    restarted, so sequence numbers regressed and the client must
    resynchronize). *)
val samples_after : t -> after_seq:int option -> Exchange_stats.t list

(** [response t ~query] packages {!samples_after} and {!latest_seq} as a
    {!Jsip_dashboard_protocol.Recent_samples.Response}, ready for the RPC
    implementation in {!Web_server}. *)
val response
  :  t
  -> query:Jsip_dashboard_protocol.Recent_samples.Query.t
  -> Jsip_dashboard_protocol.Recent_samples.Response.t
