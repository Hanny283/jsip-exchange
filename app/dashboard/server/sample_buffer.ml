open! Core
open! Async
open Jsip_types
module Recent_samples = Jsip_dashboard_protocol.Recent_samples

type t =
  { capacity : int
  ; samples : Exchange_stats.t Fdeque.t
  (* Oldest at the front, newest at the back. *)
  }
[@@deriving sexp_of]

let create ~capacity =
  if capacity <= 0
  then
    raise_s
      [%message
        "Sample_buffer.create: capacity must be positive" (capacity : int)];
  { capacity; samples = Fdeque.empty }
;;

let add t sample =
  let samples = Fdeque.enqueue_back t.samples sample in
  let samples =
    if Fdeque.length samples > t.capacity
    then Fdeque.drop_front_exn samples
    else samples
  in
  { t with samples }
;;

let latest_seq t =
  Fdeque.peek_back t.samples
  |> Option.map ~f:(fun (sample : Exchange_stats.t) -> sample.seq)
;;

let samples_after t ~after_seq =
  (* [Fdeque]'s container operations run front to back, so this list is
     oldest first. *)
  let all = Fdeque.to_list t.samples in
  match after_seq with
  | None -> all
  | Some cursor ->
    (match latest_seq t with
     | Some latest when cursor > latest ->
       (* A cursor from before an exchange restart: sequence numbers
          regressed, so resend everything we have. *)
       all
     | None | Some (_ : int) ->
       List.filter all ~f:(fun (sample : Exchange_stats.t) ->
         sample.seq > cursor))
;;

let response t ~query =
  let { Recent_samples.Query.after_seq } = query in
  { Recent_samples.Response.samples = samples_after t ~after_seq
  ; latest_seq = latest_seq t
  }
;;
