open! Core
open Bonsai_web
open Bonsai.Let_syntax
open Jsip_dashboard_protocol

module Status = struct
  type t =
    | Waiting
    | Connected
    | Failing of Error.t
  [@@deriving sexp_of, equal]
end

module Action = struct
  type t =
    | Response_received of Recent_samples.Response.t
    | Reset
    (** Empty the window but keep the cursor; the panes clear and refill only
        with samples produced after the reset (see {!Dashboard_state.clear}). *)
  [@@deriving sexp_of]
end

let window = Time_ns.Span.of_sec 120.
let poll_every = Time_ns.Span.of_sec 1.

let component (local_ graph) =
  let state, inject =
    Bonsai.state_machine
      ~default_model:(Dashboard_state.create ~window)
      ~apply_action:(fun _ctx model (action : Action.t) ->
        match action with
        | Response_received response ->
          Dashboard_state.handle_response model response
        | Reset -> Dashboard_state.clear model)
      graph
  in
  let query =
    let%arr state in
    { Recent_samples.Query.after_seq = Dashboard_state.latest_seq state }
  in
  let on_response_received =
    let%arr inject in
    fun (_ : Recent_samples.Query.t)
      (response : Recent_samples.Response.t Or_error.t) ->
      match response with
      | Ok response -> inject (Action.Response_received response)
      | Error (_ : Error.t) ->
        (* The poll result below already surfaces the error as
           [Status.Failing]; there is nothing to fold into the model. *)
        Effect.Ignore
  in
  let poll_result =
    Rpc_effect.Rpc.poll
      Recent_samples.rpc
      ~equal_query:[%equal: Recent_samples.Query.t]
      ~on_response_received
      ~every:(Bonsai.return poll_every)
      ~output_type:Response_state
      query
      graph
  in
  let status =
    match%arr poll_result with
    | No_response_yet -> Status.Waiting
    | Ok (_ : Recent_samples.Response.t) -> Status.Connected
    | Error { error; last_ok_response = _ } -> Status.Failing error
  in
  let reset =
    let%arr inject in
    inject Action.Reset
  in
  state, status, reset
;;
