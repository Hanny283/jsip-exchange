open! Core
open! Async
module Scenario_control = Jsip_dashboard_protocol.Scenario_control
module Run_state = Scenario_control.Run_state

(* How long to give a child to exit on SIGTERM before escalating to SIGKILL. *)
let stop_grace = Time_ns.Span.of_sec 2.

(* The single live child, if any. [wait] is the one-and-only {!Process.wait}
   deferred for [process] — created once so both the exit watcher and {!stop}
   can bind it without calling [waitpid] twice on the same pid. [generation]
   tags this child so a watcher can tell whether the child it is watching is
   still the current one. *)
type current =
  { process : Process.t
  ; running : Run_state.Running.t
  ; generation : int
  ; wait : Unix.Exit_or_signal.t Deferred.t
  }

type t =
  { exchange_port : int
  ; runner_exe : string
  ; mutable current : current option
  ; mutable last_error : string option
  ; mutable generation : int
  }

let create ~exchange_port ~runner_exe =
  { exchange_port
  ; runner_exe
  ; current = None
  ; last_error = None
  ; generation = 0
  }
;;

let list (_ : t) = Scenario_catalog.all

(* Message recorded in [last_error] when a child exits without our asking. A
   clean exit is benign; a nonzero exit or a signal carries the status. *)
let exit_message ~name (exit : Unix.Exit_or_signal.t) =
  match exit with
  | Ok () -> [%string "scenario %{name} exited"]
  | Error _ ->
    Sexp.to_string_hum
      [%message "scenario exited" ~name (exit : Unix.Exit_or_signal.t)]
;;

(* Forward the child's stdout and stderr, line by line, to the server log so
   a scenario's own diagnostics show up in the dashboard server's output.
   Draining these also relieves pushback on the child. *)
let drain_output ~name process =
  let log_lines reader =
    don't_wait_for
      (Pipe.iter_without_pushback (Reader.lines reader) ~f:(fun line ->
         Log.Global.info_s [%message "scenario output" ~name (line : string)]))
  in
  log_lines (Process.stdout process);
  log_lines (Process.stderr process)
;;

let stop t =
  match t.current with
  | None -> return (Ok ())
  | Some c ->
    (* Detach the child and advance the generation first, so the exit watcher
       sees either [None] or a newer generation and stays quiet: this is a
       deliberate stop, not an unexpected exit. *)
    t.current <- None;
    t.generation <- t.generation + 1;
    Process.send_signal c.process Signal.term;
    (match%bind Clock_ns.with_timeout stop_grace c.wait with
     | `Result (_ : Unix.Exit_or_signal.t) -> return (Ok ())
     | `Timeout ->
       Process.send_signal c.process Signal.kill;
       let%bind (_ : Unix.Exit_or_signal.t) = c.wait in
       return (Ok ()))
;;

let run t ~name ~seed =
  match Scenario_catalog.is_known name with
  | false ->
    return
      (Or_error.error_s [%message "unknown scenario" ~name:(name : string)])
  | true ->
    (* Kill any currently-running child before spawning the next. *)
    let%bind (_ : unit Or_error.t) = stop t in
    let args =
      [ "-scenario"
      ; name
      ; "-port"
      ; Int.to_string t.exchange_port
      ; "-seed"
      ; Int.to_string seed
      ]
    in
    (match%bind Process.create ~prog:t.runner_exe ~args () with
     | Error _ as err -> return err
     | Ok process ->
       let generation = t.generation + 1 in
       t.generation <- generation;
       let running : Run_state.Running.t = { name; seed } in
       let wait = Process.wait process in
       t.current <- Some { process; running; generation; wait };
       t.last_error <- None;
       drain_output ~name process;
       don't_wait_for
         (let%map (exit : Unix.Exit_or_signal.t) = wait in
          (* Only record the exit if THIS child is still current; a stop or a
             newer run will have moved [current] on. *)
          match t.current with
          | None -> ()
          | Some c ->
            (match c.generation = generation with
             | false -> ()
             | true ->
               t.last_error <- Some (exit_message ~name exit);
               t.current <- None));
       return (Ok ()))
;;

let status t : Run_state.t =
  let running = Option.map t.current ~f:(fun c -> c.running) in
  { running; last_error = t.last_error }
;;
