open! Core
open Async_rpc_kernel

module Category = struct
  type t =
    | Baseline
    | Market_event
    | Pathological
  [@@deriving bin_io, sexp, equal, enumerate]
end

module Scenario_info = struct
  type t =
    { name : string
    ; blurb : string
    ; expected : string list
    ; category : Category.t
    }
  [@@deriving bin_io, sexp, equal]
end

module Run_request = struct
  type t =
    { name : string
    ; seed : int
    }
  [@@deriving bin_io, sexp, equal]
end

module Run_state = struct
  module Running = struct
    type t =
      { name : string
      ; seed : int
      }
    [@@deriving bin_io, sexp, equal]
  end

  type t =
    { running : Running.t option
    ; last_error : string option
    }
  [@@deriving bin_io, sexp, equal]
end

let list_scenarios_rpc =
  Rpc.Rpc.create
    ~name:"dashboard-list-scenarios"
    ~version:1
    ~bin_query:Unit.bin_t
    ~bin_response:(List.bin_t Scenario_info.bin_t)
    ~include_in_error_count:Only_on_exn
;;

let run_scenario_rpc =
  Rpc.Rpc.create
    ~name:"dashboard-run-scenario"
    ~version:1
    ~bin_query:Run_request.bin_t
    ~bin_response:(Or_error.bin_t Unit.bin_t)
    ~include_in_error_count:Only_on_exn
;;

let stop_scenario_rpc =
  Rpc.Rpc.create
    ~name:"dashboard-stop-scenario"
    ~version:1
    ~bin_query:Unit.bin_t
    ~bin_response:(Or_error.bin_t Unit.bin_t)
    ~include_in_error_count:Only_on_exn
;;

let scenario_status_rpc =
  Rpc.Rpc.create
    ~name:"dashboard-scenario-status"
    ~version:1
    ~bin_query:Unit.bin_t
    ~bin_response:Run_state.bin_t
    ~include_in_error_count:Only_on_exn
;;
