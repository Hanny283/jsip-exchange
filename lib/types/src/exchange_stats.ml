open! Core

module Gc_stats = struct
  type t =
    { live_words : int
    ; heap_words : int
    ; minor_collections : int
    ; major_collections : int
    ; promoted_words : int
    ; compactions : int
    }
  [@@deriving sexp_of, bin_io]

  let of_stat (stat : Gc.Stat.t) =
    { live_words = stat.live_words
    ; heap_words = stat.heap_words
    ; minor_collections = stat.minor_collections
    ; major_collections = stat.major_collections
    ; (* Truncation is exact: GC word counts are far below 2^53, the largest
         integer a float represents exactly. *)
      promoted_words = Float.to_int stat.promoted_words
    ; compactions = stat.compactions
    }
  ;;
end

module Latencies = struct
  type t =
    { submit : Span_histogram.t
    ; cancel : Span_histogram.t
    }
  [@@deriving sexp_of, bin_io]
end

module Pipe_occupancy = struct
  type t =
    { request_queue : int
    ; audit_subscribers : int list
    ; market_data_subscribers : (Symbol.t * int list) list
    ; sessions : (Participant.t * int) list
    ; stats_subscribers : int list
    }
  [@@deriving sexp_of, bin_io]
end

module Participant_stats = struct
  type t =
    { orders_submitted : int
    ; cancels_submitted : int
    ; resting_orders : int
    }
  [@@deriving sexp_of, bin_io]
end

module Side_depth = struct
  type t =
    { total_size : Size.t
    ; order_count : int
    }
  [@@deriving sexp_of, bin_io]
end

module Book_depth = struct
  type t =
    { bbo : Bbo.t
    ; bids : Side_depth.t
    ; asks : Side_depth.t
    }
  [@@deriving sexp_of, bin_io]
end

module Loop_stats = struct
  type t =
    { iterations : int
    ; gap : Span_histogram.t
    }
  [@@deriving sexp_of, bin_io]
end

type t =
  { seq : int
  ; sampled_at : Time_ns.Stable.V1.t
  ; gc : Gc_stats.t
  ; latencies : Latencies.t
  ; pipes : Pipe_occupancy.t
  ; participants : (Participant.t * Participant_stats.t) list
  ; books : (Symbol.t * Book_depth.t) list
  ; fundamentals : (Symbol.t * Price.t) list
  ; loop : Loop_stats.t
  }
[@@deriving sexp_of, bin_io]
