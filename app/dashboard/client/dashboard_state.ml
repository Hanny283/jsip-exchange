open! Core
open Jsip_types
module Recent_samples = Jsip_dashboard_protocol.Recent_samples

(* Trends compare the newest sample against the one roughly this far back;
   the memory sparkline shows a fixed slice of this length; rates average
   per-interval counts over this many trailing samples. *)
let trend_lookback = Time_ns.Span.of_int_sec 10
let memory_slice = Time_ns.Span.of_int_sec 60
let rate_window_samples = 10

(* A queue must move by more than
   [max trend_min_step (older / trend_step_denominator)] to count as rising
   or falling: an absolute floor so tiny queues don't flap, a 20% band so big
   ones need a proportional move. *)
let trend_min_step = 5
let trend_step_denominator = 5

type t =
  { window : Time_ns.Span.t
  ; samples : Exchange_stats.t list (* ascending [seq]; newest last *)
  ; cursor : int option
  (* Highest [seq] folded so far — normally the newest sample's [seq], but it
     outlives eviction and, crucially, [clear]: a cleared window keeps the
     cursor so the next query asks only for newer samples instead of
     re-pulling the whole buffer. *)
  }
[@@deriving sexp_of]

let create ~window = { window; samples = []; cursor = None }
let sample_count t = List.length t.samples
let newest t = List.last t.samples

(* [clear] empties the window but keeps [cursor] (and [window]): the panes
   render their empty states, and because the query still asks for samples
   after [cursor], the next polls refill only with snapshots produced after
   the clear — a clean slate rather than the buffered history replayed. *)
let clear t = { t with samples = [] }
let latest_seq t = t.cursor

let symbols t =
  List.concat_map t.samples ~f:(fun (sample : Exchange_stats.t) ->
    List.map sample.books ~f:fst)
  |> List.dedup_and_sort ~compare:Symbol_id.compare
;;

(* A [seq] below our cursor can only mean the snapshot numbering started over
   — i.e. the server or exchange restarted. Equal seqs are mere duplicates
   and are dropped by [handle_response] instead. *)
let restart_detected t (response : Recent_samples.Response.t) =
  match latest_seq t with
  | None -> false
  | Some cursor ->
    let latest_regressed =
      match response.latest_seq with
      | None -> false
      | Some latest -> latest < cursor
    in
    latest_regressed
    || List.exists response.samples ~f:(fun (sample : Exchange_stats.t) ->
      sample.seq < cursor)
;;

let evict t =
  match newest t with
  | None -> t
  | Some (newest_sample : Exchange_stats.t) ->
    let horizon = Time_ns.sub newest_sample.sampled_at t.window in
    { t with
      samples =
        List.filter t.samples ~f:(fun (sample : Exchange_stats.t) ->
          Time_ns.( >= ) sample.sampled_at horizon)
    }
;;

let handle_response t (response : Recent_samples.Response.t) =
  let t =
    match restart_detected t response with
    (* Numbering began again below our cursor: drop the old window and the
       cursor so the new, lower sequence re-baselines cleanly. *)
    | true -> { t with samples = []; cursor = None }
    | false -> t
  in
  let rev_samples =
    (* Fold newest-first so "is this sample newer than everything we hold?"
       is a head check; this also drops duplicates and out-of-order entries
       within a single response. *)
    List.fold
      response.samples
      ~init:(List.rev t.samples)
      ~f:(fun rev_samples (sample : Exchange_stats.t) ->
        match rev_samples with
        | (held : Exchange_stats.t) :: _ when sample.seq <= held.seq ->
          rev_samples
        | _ -> sample :: rev_samples)
  in
  let t = evict { t with samples = List.rev rev_samples } in
  (* Advance the cursor to the newest sample now held. It never regresses via
     eviction (the newest sample is never evicted) and persists through
     [clear], so the query cursor only ever moves forward within a run. *)
  let cursor =
    match newest t with
    | Some (sample : Exchange_stats.t) -> Some sample.seq
    | None -> t.cursor
  in
  { t with cursor }
;;

(* The "before" sample for trends: the newest sample at least
   [trend_lookback] older than [newest], or the oldest sample when the window
   is shorter than the lookback. Only called on non-empty windows, so
   [hd_exn] cannot raise. *)
let lookback_sample t ~newest:(newest_sample : Exchange_stats.t) =
  let cutoff = Time_ns.sub newest_sample.sampled_at trend_lookback in
  let old_enough =
    List.filter t.samples ~f:(fun (sample : Exchange_stats.t) ->
      Time_ns.( <= ) sample.sampled_at cutoff)
  in
  match List.last old_enough with
  | Some sample -> sample
  | None -> List.hd_exn t.samples
;;

(* Up to the [count] newest samples, oldest first. *)
let last_samples t ~count =
  List.drop t.samples (Int.max 0 (sample_count t - count))
;;

module Trend = struct
  type t =
    | Rising
    | Flat
    | Falling
  [@@deriving sexp_of, equal]

  let classify ~newer ~older =
    let step = Int.max trend_min_step (older / trend_step_denominator) in
    if newer > older + step
    then Rising
    else if newer < older - step
    then Falling
    else Flat
  ;;
end

module Memory_view = struct
  type t =
    { points : float list
    ; live_words : int option
    ; growth_words_per_sec : float option
    }
  [@@deriving sexp_of, equal]
end

let memory_view t : Memory_view.t =
  match newest t with
  | None -> { points = []; live_words = None; growth_words_per_sec = None }
  | Some (newest_sample : Exchange_stats.t) ->
    let horizon = Time_ns.sub newest_sample.sampled_at memory_slice in
    let slice =
      List.filter t.samples ~f:(fun (sample : Exchange_stats.t) ->
        Time_ns.( >= ) sample.sampled_at horizon)
    in
    let points =
      List.map slice ~f:(fun (sample : Exchange_stats.t) ->
        Float.of_int sample.gc.live_words)
    in
    let growth_words_per_sec =
      match slice with
      | [] | [ _ ] -> None
      | (first : Exchange_stats.t) :: _ ->
        let last : Exchange_stats.t = List.last_exn slice in
        let seconds =
          Time_ns.Span.to_sec (Time_ns.diff last.sampled_at first.sampled_at)
        in
        (match Float.( > ) seconds 0. with
         | false -> None
         | true ->
           Some
             (Float.of_int (last.gc.live_words - first.gc.live_words)
              /. seconds))
    in
    { points
    ; live_words = Some newest_sample.gc.live_words
    ; growth_words_per_sec
    }
;;

module Latency_view = struct
  type t =
    { p50 : Time_ns.Span.t option
    ; p90 : Time_ns.Span.t option
    ; p99 : Time_ns.Span.t option
    ; buckets : (string * int) list
    ; total : int
    }
  [@@deriving sexp_of, equal]
end

let first_bucket_label = "<1us"
let overflow_bucket_label = ">=16.8s"

let bucket_label index =
  if index = 0
  then first_bucket_label
  else if index = Span_histogram.num_buckets - 1
  then overflow_bucket_label
  else (
    let lower = Span_histogram.bucket_boundaries.(index - 1) in
    let upper = Span_histogram.bucket_boundaries.(index) in
    [%string "%{lower#Time_ns.Span}-%{upper#Time_ns.Span}"])
;;

let merged_histogram t ~select =
  List.fold
    t.samples
    ~init:(Span_histogram.create ())
    ~f:(fun merged sample -> Span_histogram.merge merged (select sample))
;;

let latency_view t ~select : Latency_view.t =
  let merged = merged_histogram t ~select in
  let buckets =
    Array.to_list (Span_histogram.counts merged)
    |> List.filter_mapi ~f:(fun index count ->
      match count with 0 -> None | _ -> Some (bucket_label index, count))
  in
  { p50 = Span_histogram.percentile merged ~percentile:50.
  ; p90 = Span_histogram.percentile merged ~percentile:90.
  ; p99 = Span_histogram.percentile merged ~percentile:99.
  ; buckets
  ; total = Span_histogram.total_count merged
  }
;;

let submit_latency_view t =
  latency_view t ~select:(fun (sample : Exchange_stats.t) ->
    sample.latencies.submit)
;;

let cancel_latency_view t =
  latency_view t ~select:(fun (sample : Exchange_stats.t) ->
    sample.latencies.cancel)
;;

module Occupancy_view = struct
  module Row = struct
    type t =
      { name : string
      ; length : int
      ; trend : Trend.t
      }
    [@@deriving sexp_of, equal]
  end

  type t = Row.t list [@@deriving sexp_of, equal]
end

(* Flattens one sample's pipe occupancies into (display name, length) rows.
   Destructuring the record means a new kind of pipe is a compile error here
   rather than a silently missing row. *)
let occupancy_rows (sample : Exchange_stats.t) =
  let indexed prefix lengths =
    List.mapi lengths ~f:(fun i length ->
      [%string "%{prefix}[%{i#Int}]"], length)
  in
  let { Exchange_stats.Pipe_occupancy.request_queue
      ; audit_subscribers
      ; market_data_subscribers
      ; sessions
      ; stats_subscribers
      }
    =
    sample.pipes
  in
  List.concat
    [ [ "request-queue", request_queue ]
    ; indexed "audit" audit_subscribers
    ; List.concat_map market_data_subscribers ~f:(fun (symbol, lengths) ->
        indexed [%string "md:%{symbol#Symbol_id}"] lengths)
    ; List.map sessions ~f:(fun (participant, length) ->
        [%string "session:%{participant#Participant}"], length)
    ; indexed "stats" stats_subscribers
    ]
;;

let occupancy_view t : Occupancy_view.t =
  match newest t with
  | None -> []
  | Some newest_sample ->
    let older = lookback_sample t ~newest:newest_sample in
    let older_lengths =
      (* Names are unique within a sample (sorted keys, distinct indices),
         but a duplicate would only skew one trend, so keep the first rather
         than raise. *)
      String.Map.of_alist_reduce
        (occupancy_rows older)
        ~f:(fun first _duplicate -> first)
    in
    List.map (occupancy_rows newest_sample) ~f:(fun (name, length) ->
      let trend =
        match Map.find older_lengths name with
        | None -> Trend.Flat
        | Some older_length ->
          Trend.classify ~newer:length ~older:older_length
      in
      { Occupancy_view.Row.name; length; trend })
;;

module Participants_view = struct
  module Row = struct
    type t =
      { participant : Participant.t
      ; orders_per_sec : float
      ; cancels_per_sec : float
      ; resting_orders : int
      }
    [@@deriving sexp_of, equal]
  end

  type t = Row.t list [@@deriving sexp_of, equal]
end

let participants_view t : Participants_view.t =
  match newest t with
  | None -> []
  | Some (newest_sample : Exchange_stats.t) ->
    let recent = last_samples t ~count:rate_window_samples in
    let interval_count = List.length recent in
    let stats_for (sample : Exchange_stats.t) participant =
      List.Assoc.find
        sample.participants
        participant
        ~equal:Participant.equal
    in
    let participants =
      List.concat_map recent ~f:(fun (sample : Exchange_stats.t) ->
        List.map sample.participants ~f:fst)
      |> List.dedup_and_sort ~compare:Participant.compare
    in
    List.map participants ~f:(fun participant ->
      let mean_of field =
        let total =
          List.sum (module Int) recent ~f:(fun sample ->
            match stats_for sample participant with
            | None -> 0
            | Some stats -> field stats)
        in
        Float.of_int total /. Float.of_int interval_count
      in
      let orders_per_sec =
        mean_of (fun (stats : Exchange_stats.Participant_stats.t) ->
          stats.orders_submitted)
      in
      let cancels_per_sec =
        mean_of (fun (stats : Exchange_stats.Participant_stats.t) ->
          stats.cancels_submitted)
      in
      let resting_orders =
        match stats_for newest_sample participant with
        | None -> 0
        | Some (stats : Exchange_stats.Participant_stats.t) ->
          stats.resting_orders
      in
      { Participants_view.Row.participant
      ; orders_per_sec
      ; cancels_per_sec
      ; resting_orders
      })
;;

module Depth_view = struct
  type t =
    { bbo : Bbo.t option
    ; bid_size : Size.t
    ; bid_orders : int
    ; ask_size : Size.t
    ; ask_orders : int
    }
  [@@deriving sexp_of, equal]
end

let depth_view t ~symbol : Depth_view.t option =
  match newest t with
  | None -> None
  | Some (newest_sample : Exchange_stats.t) ->
    (match
       List.Assoc.find newest_sample.books symbol ~equal:Symbol_id.equal
     with
     | None -> None
     | Some (depth : Exchange_stats.Book_depth.t) ->
       let bbo =
         match Bbo.equal depth.bbo Bbo.empty with
         | true -> None
         | false -> Some depth.bbo
       in
       Some
         { Depth_view.bbo
         ; bid_size = depth.bids.total_size
         ; bid_orders = depth.bids.order_count
         ; ask_size = depth.asks.total_size
         ; ask_orders = depth.asks.order_count
         })
;;

module Price_view = struct
  module Point = struct
    type t =
      { market : Price.t option
      ; fundamental : Price.t option
      }
    [@@deriving sexp_of, equal]
  end

  type t = Point.t list [@@deriving sexp_of, equal]
end

(* The midpoint of the touch, wrapped as a [Price.t]; [None] unless both
   sides are populated. The exchange has no single canonical "price", so the
   pane treats the bbo mid as what the market sees — mirroring the shape of
   {!Bbo.spread} and [observed_mid_of_bbo] in the pump-and-dump bot. *)
let bbo_mid (bbo : Bbo.t) =
  match bbo.bid, bbo.ask with
  | Some (bid : Level.t), Some (ask : Level.t) ->
    Some
      (Price.of_int_cents
         ((Price.to_int_cents bid.price + Price.to_int_cents ask.price) / 2))
  | _ -> None
;;

(* One point per sample across the whole window, oldest first: the observed
   market mid and the oracle fundamental for [symbol]. Either can be [None]
   for a given sample (no book row, a one-sided book, or no fundamental),
   which the pane renders as a break in that line. *)
let price_view t ~symbol : Price_view.t =
  List.map t.samples ~f:(fun (sample : Exchange_stats.t) ->
    let market =
      match List.Assoc.find sample.books symbol ~equal:Symbol_id.equal with
      | None -> None
      | Some (depth : Exchange_stats.Book_depth.t) -> bbo_mid depth.bbo
    in
    let fundamental =
      List.Assoc.find sample.fundamentals symbol ~equal:Symbol_id.equal
    in
    { Price_view.Point.market; fundamental })
;;

module Loop_view = struct
  type t =
    { p50 : Time_ns.Span.t option
    ; p99 : Time_ns.Span.t option
    ; max_gap_points : float list
    ; iterations_per_sec : float option
    }
  [@@deriving sexp_of, equal]
end

(* The upper boundary, in seconds, of the highest non-empty bucket — an upper
   bound on the worst observation. The overflow bucket has no upper boundary,
   so it reports the last boundary (a lower bound). *)
let max_gap_seconds histogram =
  match Span_histogram.is_empty histogram with
  | true -> 0.
  | false ->
    let highest_non_empty =
      Array.foldi
        (Span_histogram.counts histogram)
        ~init:0
        ~f:(fun index highest count ->
          match count with 0 -> highest | _ -> index)
    in
    let boundaries = Span_histogram.bucket_boundaries in
    let boundary_index =
      Int.min highest_non_empty (Array.length boundaries - 1)
    in
    Time_ns.Span.to_sec boundaries.(boundary_index)
;;

let loop_view t : Loop_view.t =
  let merged =
    merged_histogram t ~select:(fun (sample : Exchange_stats.t) ->
      sample.loop.gap)
  in
  let max_gap_points =
    List.map t.samples ~f:(fun (sample : Exchange_stats.t) ->
      max_gap_seconds sample.loop.gap)
  in
  let iterations_per_sec =
    match last_samples t ~count:rate_window_samples with
    | [] -> None
    | recent ->
      let total =
        List.sum (module Int) recent ~f:(fun (sample : Exchange_stats.t) ->
          sample.loop.iterations)
      in
      Some (Float.of_int total /. Float.of_int (List.length recent))
  in
  { p50 = Span_histogram.percentile merged ~percentile:50.
  ; p99 = Span_histogram.percentile merged ~percentile:99.
  ; max_gap_points
  ; iterations_per_sec
  }
;;
