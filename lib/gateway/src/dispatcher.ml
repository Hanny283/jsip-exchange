open! Core
open! Async
open Jsip_types

type t =
  { market_data_subscribers_by_symbol :
      Exchange_event.t Pipe.Writer.t Bag.t Symbol.Table.t
  ; audit_subscribers : Exchange_event.t Pipe.Writer.t Bag.t
  ; sessions : Session.t Participant.Table.t
  }

let create () =
  { market_data_subscribers_by_symbol = Symbol.Table.create ()
  ; audit_subscribers = Bag.create ()
  ; sessions = Participant.Table.create ()
  }
;;

let find_session (t : t) participant = Hashtbl.find t.sessions participant

(* Tear down a session: close its outbound pipe and drop it from the registry
   so the participant's name is free to log in again. The [phys_equal] guard
   means a stale connection's close hook can't evict a newer session that has
   since taken the same name. *)
let clean_up_session (t : t) (session : Session.t) : unit Deferred.t =
  let participant = Session.participant session in
  Session.close session;
  (match Hashtbl.find t.sessions participant with
   | Some current when phys_equal current session ->
     Hashtbl.remove t.sessions participant
   | _ -> ());
  Deferred.return ()
;;

let set_up_session (t : t) (participant : Participant.t) : unit Deferred.t =
  (* Callers (the login handler) only reach here once they've decided it's
     safe to (re)register — i.e. no live session already holds this name. A
     leftover closed session is cleaned up first so the [Hashtbl.set] below
     installs a fresh one. *)
  let%bind () =
    match Hashtbl.find t.sessions participant with
    | None -> Deferred.return ()
    | Some existing -> clean_up_session t existing
  in
  Hashtbl.set t.sessions ~key:participant ~data:(Session.create participant);
  Deferred.return ()
;;

let subscribe_market_data t symbols =
  let reader, writer = Pipe.create () in
  (* Register the same writer in every requested symbol's bag. A per-symbol
     publish iterates a single bag, so a subscriber listed in multiple bags
     receives each event exactly once — only via whichever bag matches the
     event's symbol. *)
  let elts =
    List.map symbols ~f:(fun symbol ->
      let subscribers =
        Hashtbl.find_or_add
          t.market_data_subscribers_by_symbol
          ~default:Bag.create
          symbol
      in
      symbol, Bag.add subscribers writer)
  in
  don't_wait_for
    (let%map () = Pipe.closed writer in
     List.iter elts ~f:(fun (symbol, elt) ->
       match Hashtbl.find t.market_data_subscribers_by_symbol symbol with
       | None -> ()
       | Some subscribers -> Bag.remove subscribers elt));
  reader
;;

let subscribe_audit t =
  let reader, writer = Pipe.create () in
  let elt = Bag.add t.audit_subscribers writer in
  don't_wait_for
    (let%map () = Pipe.closed writer in
     Bag.remove t.audit_subscribers elt);
  reader
;;

let push_market_data t event symbol =
  match Hashtbl.find t.market_data_subscribers_by_symbol symbol with
  | None -> ()
  | Some subscribers ->
    Bag.iter subscribers ~f:(fun writer ->
      Pipe.write_without_pushback_if_open writer event)
;;

let push_audit t event =
  Bag.iter t.audit_subscribers ~f:(fun writer ->
    Pipe.write_without_pushback_if_open writer event)
;;

let push_to_session t participant event =
  match Hashtbl.find t.sessions participant with
  | None -> ()
  | Some session -> Session.push session event
;;

let dispatch_event t (event : Exchange_event.t) =
  push_audit t event;
  match event with
  | Cancel_reject { participant; client_order_id = _; reason = _ } ->
    push_to_session t participant event
  | Best_bid_offer_update { symbol; bbo = _ } ->
    push_market_data t event symbol
  | Trade_report { symbol; price = _; size = _ } ->
    push_market_data t event symbol
  | Order_accept { order_id = _; request }
  | Order_reject { request; reason = _ } ->
    push_to_session t request.participant event
  | Order_cancel
      { order_id = _
      ; participant
      ; symbol = _
      ; remaining_size = _
      ; reason = _
      ; client_order_id = _
      } ->
    push_to_session t participant event
  | Fill
      { fill_id = _
      ; symbol = _
      ; price = _
      ; size = _
      ; aggressor_order_id = _
      ; aggressor_participant
      ; aggressor_side = _
      ; resting_order_id = _
      ; resting_participant
      ; aggressor_client_order_id = _
      ; resting_client_order_id = _
      } ->
    push_to_session t aggressor_participant event;
    push_to_session t resting_participant event
;;

let dispatch t events = List.iter events ~f:(dispatch_event t)

(* Introspection: [Pipe.length] works on either end of a pipe, so we can
   measure occupancy from the writer halves we hold (and, for sessions, from
   the reader that [Session.reader] exposes) without touching the
   subscribers' readers. *)

let audit_pipe_lengths t =
  Bag.to_list t.audit_subscribers |> List.map ~f:Pipe.length
;;

let market_data_pipe_lengths t =
  Hashtbl.to_alist t.market_data_subscribers_by_symbol
  |> List.map ~f:(fun (symbol, subscribers) ->
    symbol, Bag.to_list subscribers |> List.map ~f:Pipe.length)
  |> List.sort ~compare:(fun (s1, _) (s2, _) -> Symbol.compare s1 s2)
;;

let session_pipe_lengths t =
  Hashtbl.to_alist t.sessions
  |> List.map ~f:(fun (participant, session) ->
    participant, Pipe.length (Session.reader session))
  |> List.sort ~compare:(fun (p1, _) (p2, _) -> Participant.compare p1 p2)
;;

module For_testing = struct
  let audit_subscriber_count t = Bag.length t.audit_subscribers
end
