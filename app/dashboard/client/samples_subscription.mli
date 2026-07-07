(** The dashboard's single data feed: polls the dashboard server's
    {!Jsip_dashboard_protocol.Recent_samples} RPC and folds every response
    into a {!Dashboard_state.t}.

    This is the only client module that talks to [Rpc_effect]; every pane
    derives its view from the returned model. The wiring is:

    - a [Bonsai.state_machine] holds the {!Dashboard_state.t} (a two-minute
      window of samples);
    - the query is derived from the model — its [after_seq] cursor is
      {!Dashboard_state.latest_seq} — so each poll fetches only samples the
      client has not seen;
    - [Rpc_effect.Rpc.poll] dispatches once a second over the page's own
      websocket (no [where_to_connect]: it defaults to the server that served
      the page) with at most one request in flight, and each [Ok] response is
      injected back into the state machine.

    Poll cadence caveat: [poll] also re-dispatches whenever the query
    changes, and every response that carries samples advances the cursor,
    changing the query — so each productive poll is typically followed by one
    immediate extra poll that returns zero samples. That bounds the request
    rate at roughly two per second, which is fine for this dashboard; don't
    "fix" the cursor to avoid it. *)

open! Core
open Bonsai_web

(** Connection health as the banner reports it, derived from the poll's
    {!Rpc_effect.Poll_result.Response_state}. *)
module Status : sig
  type t =
    | Waiting (** No response yet — the first poll is still in flight. *)
    | Connected (** The most recent poll succeeded. *)
    | Failing of Error.t
    (** The most recent poll failed (server down, websocket dropped). Panes
        keep rendering the last good window. *)
  [@@deriving sexp_of, equal]
end

(** [component graph] starts the once-a-second poll and returns the
    continuously updated model together with the connection status. *)
val component
  :  local_ Bonsai.graph
  -> Dashboard_state.t Bonsai.t * Status.t Bonsai.t
