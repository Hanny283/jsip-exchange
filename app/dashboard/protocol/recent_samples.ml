open! Core
open Async_rpc_kernel
open Jsip_types

module Query = struct
  type t = { after_seq : int option } [@@deriving bin_io, sexp, equal]
end

module Response = struct
  type t =
    { samples : Exchange_stats.t list
    ; latest_seq : int option
    }
  [@@deriving bin_io, sexp_of]
end

let rpc =
  Rpc.Rpc.create
    ~name:"dashboard-recent-samples"
    ~version:1
    ~bin_query:Query.bin_t
    ~bin_response:Response.bin_t
    ~include_in_error_count:Only_on_exn
;;
