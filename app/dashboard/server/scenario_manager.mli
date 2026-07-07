(** Spawns and kills the [scenario_runner] child process behind the
    dashboard's scenario-control RPCs.

    {!Jsip_scenario_runner.Runner.run} boots its {b own} exchange server on
    the port it is given, so the dashboard does not run a scenario
    in-process: it launches [scenario_runner] as a child process on the
    exchange port the dashboard already monitors, and switching scenarios
    means killing that child and spawning a new one. The dashboard's exchange
    feed reconnects and its state model resets on the sequence regression, so
    the panes clear cleanly across the switch.

    At most one child is live at a time. A run request whose name is not in
    {!Scenario_catalog} is rejected before any process is spawned, and the
    child is spawned with its arguments as a list (no shell), so this is a
    local-only control surface with no command injection surface.

    Wire the four RPCs in {!Jsip_dashboard_protocol.Scenario_control} to
    {!list}, {!run}, {!stop}, and {!status}; {!Web_server} does exactly that.
    The owner (see [main.ml]) is responsible for calling {!stop} at shutdown
    so the child dies with the server. *)

open! Core
open! Async
module Scenario_control = Jsip_dashboard_protocol.Scenario_control

type t

(** [create ~exchange_port ~runner_exe] builds an idle manager. [runner_exe]
    is the path to the compiled [scenario_runner] binary; each launched child
    is told to listen on [exchange_port] (via [-port]) — the same port the
    dashboard's exchange feed connects to. No process is spawned until
    {!run}. *)
val create : exchange_port:int -> runner_exe:string -> t

(** [list t] is the authored catalog ({!Scenario_catalog.all}) the client
    renders its control bar from. Pure; spawns nothing. *)
val list : t -> Scenario_control.Scenario_info.t list

(** [run t ~name ~seed] launches [name] with [seed], first killing any
    currently-running child. Returns [Error] without spawning if [name] is
    not in {!Scenario_catalog}, or if the child process fails to spawn;
    otherwise [Ok] once the child is created. A background watcher records an
    unexpected exit of this child in {!status}'s [last_error]. *)
val run : t -> name:string -> seed:int -> unit Or_error.t Deferred.t

(** [stop t] kills the running child (SIGTERM, then SIGKILL if it does not
    exit within a short grace period) and clears the running state. A no-op
    returning [Ok] when nothing is running. *)
val stop : t -> unit Or_error.t Deferred.t

(** [status t] snapshots what is live now plus the most recent launch/exit
    error, for {!Scenario_control.scenario_status_rpc}. *)
val status : t -> Scenario_control.Run_state.t
