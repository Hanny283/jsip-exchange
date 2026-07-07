(** The RPCs a browser dashboard uses to launch, stop, and inspect scenarios.

    The dashboard server monitors one exchange port. Rather than requiring
    the user to start a [scenario_runner] by hand, the server owns a
    {b scenario_manager} that spawns a [scenario_runner] child process —
    which boots its own exchange on that port — and kills it to switch
    scenarios. The browser drives that manager over this module's RPCs,
    served on the dashboard's own websocket (the same one that serves
    {!Recent_samples.rpc}).

    The authored catalog of scenarios — a blurb plus a list of predicted pane
    behaviors per scenario — lives server-side and crosses the wire as pure
    {!Scenario_info.t} values, so the browser bundle never links the
    scenario/exchange libraries and stays js_of_ocaml-safe. Like
    {!Recent_samples}, this module depends only on [Core] and
    [Async_rpc_kernel], so it links into browser clients via js_of_ocaml.

    A typical client interaction:

    {[
      (* Fetch the catalog once to render the control bar. *)
      Rpc.Rpc.dispatch Scenario_control.list_scenarios_rpc conn ()
    ]}

    {[
      (* Launch a scenario with a fixed seed. *)
      Rpc.Rpc.dispatch
        Scenario_control.run_scenario_rpc
        conn
        { Scenario_control.Run_request.name = "cancel-storm"; seed = 0 }
    ]}

    {[
      (* Poll for what is live now, plus any launch/exit error. *)
      Rpc.Rpc.dispatch Scenario_control.scenario_status_rpc conn ()
    ]}

    The wire shapes of all four RPCs are pinned by the expect test in
    [app/dashboard/test/test_protocol_shapes.ml]. *)

open! Core
open Async_rpc_kernel

(** How the dashboard groups scenarios for display. [Pathological] scenarios
    are the ones that stress a specific resource (queues, heap, subscriber
    buffers); [Market_event] scenarios script price moves; [Baseline]
    scenarios are benign references. *)
module Category : sig
  type t =
    | Baseline
    | Market_event
    | Pathological
  [@@deriving bin_io, sexp, equal, enumerate]
end

(** One catalog entry: a scenario the dashboard can launch, with authored
    guidance shown next to the live panes. [expected] is a list of one-line
    predictions, each naming a pane. *)
module Scenario_info : sig
  type t =
    { name : string (** CLI name, e.g. ["cancel-storm"] *)
    ; blurb : string (** one or two sentences: what runs *)
    ; expected : string list (** predicted pane signatures *)
    ; category : Category.t
    }
  [@@deriving bin_io, sexp, equal]
end

(** A request to launch a scenario. [name] must be one of the catalog's
    {!Scenario_info.name}s — the server validates it against the allowlist
    before spawning — and [seed] makes the run reproducible. *)
module Run_request : sig
  type t =
    { name : string
    ; seed : int
    }
  [@@deriving bin_io, sexp, equal]
end

(** A snapshot of the scenario manager's state, returned by
    {!scenario_status_rpc} so the client can render what is live and surface
    failures. *)
module Run_state : sig
  (** The scenario whose child process is currently live. *)
  module Running : sig
    type t =
      { name : string
      ; seed : int
      }
    [@@deriving bin_io, sexp, equal]
  end

  type t =
    { running : Running.t option
    (** The scenario whose child process is live now, or [None] between runs. *)
    ; last_error : string option
    (** The message from the most recent failed launch or unexpected child
        exit, cleared on the next successful launch. *)
    }
  [@@deriving bin_io, sexp, equal]
end

(** ["dashboard-list-scenarios"], version 1: fetch the authored catalog. The
    server answers from its static {!Scenario_info.t} list; the client
    fetches it (rarely) to render the control bar. *)
val list_scenarios_rpc : (unit, Scenario_info.t list) Rpc.Rpc.t

(** ["dashboard-run-scenario"], version 1: launch [name] with [seed], killing
    any currently-running scenario first. Returns [Error] if [name] is not in
    the catalog or the child process fails to spawn. *)
val run_scenario_rpc : (Run_request.t, unit Or_error.t) Rpc.Rpc.t

(** ["dashboard-stop-scenario"], version 1: kill the running scenario's child
    process, if any. A no-op (returning [Ok]) when nothing is running. *)
val stop_scenario_rpc : (unit, unit Or_error.t) Rpc.Rpc.t

(** ["dashboard-scenario-status"], version 1: report what is live now and the
    last error, if any. The client polls this about once a second. *)
val scenario_status_rpc : (unit, Run_state.t) Rpc.Rpc.t
