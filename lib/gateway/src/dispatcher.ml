open! Core
open! Async
open Jsip_types

type t =
  { market_data_subscribers_by_symbol :
      Exchange_event.t Pipe.Writer.t Bag.t Symbol.Table.t
  ; audit_subscribers : Exchange_event.t Pipe.Writer.t Bag.t
  ; sessions : Session.t Participant_id.Table.t
      (* Keyed by the interned id, not the name: session lookups on the
         dispatch path hash an int instead of a string. Events carry names,
         so routing resolves name -> id through [registry] first. *)
  ; registry : Participant_id.Registry.t
  }

let create ~registry =
  { market_data_subscribers_by_symbol = Symbol.Table.create ()
  ; audit_subscribers = Bag.create ()
  ; sessions = Participant_id.Table.create ()
  ; registry
  }
;;

let find_session (t : t) participant =
  (* A name the registry has never seen has never logged in, so it cannot
     have a session — [None] without touching the session table. *)
  match Participant_id.Registry.find t.registry participant with
  | None -> None
  | Some id -> Hashtbl.find t.sessions id
;;

(* Tear down a session: close its outbound pipe and drop it from the session
   table so the participant's name is free to log in again. The [phys_equal]
   guard means a stale connection's close hook can't evict a newer session
   that has since taken the same name. The registry is deliberately NOT
   touched: the participant keeps their id for the next login. *)
let clean_up_session (t : t) (session : Session.t) : unit Deferred.t =
  let id = Session.participant_id session in
  Session.close session;
  (match Hashtbl.find t.sessions id with
   | Some current when phys_equal current session ->
     Hashtbl.remove t.sessions id
   | _ -> ());
  Deferred.return ()
;;

let set_up_session (t : t) (participant : Participant.t) : unit Deferred.t =
  (* Callers (the login handler) only reach here once they've decided it's
     safe to (re)register — i.e. no live session already holds this name. A
     leftover closed session is cleaned up first so the [Hashtbl.set] below
     installs a fresh one. Interning here makes login the one place a name
     becomes an id; re-login finds the same id again. *)
  let id = Participant_id.Registry.intern t.registry participant in
  let%bind () =
    match Hashtbl.find t.sessions id with
    | None -> Deferred.return ()
    | Some existing -> clean_up_session t existing
  in
  Hashtbl.set
    t.sessions
    ~key:id
    ~data:(Session.create participant ~participant_id:id);
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

(* A subscriber this far behind is treated as saturated: further events for
   it are dropped rather than buffered. Two things fall out of this. The
   server's per-subscriber memory is bounded (a single slow consumer can no
   longer balloon it without limit), and — because [Exchange_server] streams
   each feed with per-event pushback so a slow subscriber's backlog collects
   in this pipe rather than the transport's send buffer — the backlog stays
   visible as pipe occupancy, capped here. A market-data or audit consumer
   that cannot keep up gets a lossy feed; that is the intended real-world
   behavior for a firehose observer. Session feeds are deliberately left
   unbounded elsewhere: they carry a participant's own fills, which must not
   be dropped. *)
let max_feed_backlog = 1024

let push_market_data t event symbol =
  match Hashtbl.find t.market_data_subscribers_by_symbol symbol with
  | None -> ()
  | Some subscribers ->
    Bag.iter subscribers ~f:(fun writer ->
      if Pipe.length writer < max_feed_backlog
      then Pipe.write_without_pushback_if_open writer event)
;;

let push_audit t event =
  Bag.iter t.audit_subscribers ~f:(fun writer ->
    if Pipe.length writer < max_feed_backlog
    then Pipe.write_without_pushback_if_open writer event)
;;

let push_to_session t participant event =
  (* Events name participants (the engine speaks names), so routing resolves
     name -> id first. [find] returning [None] means the name never logged in
     — the same drop as today's no-session case. *)
  match Participant_id.Registry.find t.registry participant with
  | None -> ()
  | Some id ->
    (match Hashtbl.find t.sessions id with
     | None -> ()
     | Some session -> Session.push session event)
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
  | Order_accept { order_id = _; participant; request = _ }
  | Order_reject { participant; request = _; reason = _ } ->
    push_to_session t participant event
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
  (* The snapshot edge speaks names: resolve back from each session (which
     carries its own name — no registry lookup needed) and keep the
     name-sorted order callers relied on before the id re-key. *)
  Hashtbl.to_alist t.sessions
  |> List.map ~f:(fun ((_ : Participant_id.t), session) ->
    Session.participant session, Pipe.length (Session.reader session))
  |> List.sort ~compare:(fun (p1, _) (p2, _) -> Participant.compare p1 p2)
;;

module For_testing = struct
  let audit_subscriber_count t = Bag.length t.audit_subscribers
end
