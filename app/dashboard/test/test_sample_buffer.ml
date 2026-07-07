open! Core
open Jsip_types
open Expect_test_helpers_core
module Sample_buffer = Jsip_dashboard_server.Sample_buffer
module Recent_samples = Jsip_dashboard_protocol.Recent_samples

(* [Sample_buffer] only ever inspects [seq], so every other field of the
   snapshot can stay at its zero value; [sampled_at] tracks [seq] just to
   keep the samples visibly distinct in any printed output. *)
let sample ~seq : Exchange_stats.t =
  { seq
  ; sampled_at = Time_ns.add Time_ns.epoch (Time_ns.Span.of_int_sec seq)
  ; gc =
      { live_words = 0
      ; heap_words = 0
      ; minor_collections = 0
      ; major_collections = 0
      ; promoted_words = 0
      ; compactions = 0
      }
  ; latencies =
      { submit = Span_histogram.create ()
      ; cancel = Span_histogram.create ()
      }
  ; pipes =
      { request_queue = 0
      ; audit_subscribers = []
      ; market_data_subscribers = []
      ; sessions = []
      ; stats_subscribers = []
      }
  ; participants = []
  ; books = []
  ; loop = { iterations = 0; gap = Span_histogram.create () }
  }
;;

let add_seqs buffer seqs =
  List.fold seqs ~init:buffer ~f:(fun buffer seq ->
    Sample_buffer.add buffer (sample ~seq))
;;

(* Buffers are compared by the [seq]s they hold; the payloads carry no other
   information here. *)
let show_seqs samples =
  print_s
    [%sexp
      (List.map samples ~f:(fun (sample : Exchange_stats.t) -> sample.seq)
       : int list)]
;;

let%expect_test "create rejects non-positive capacities" =
  require_does_raise (fun () -> Sample_buffer.create ~capacity:0);
  [%expect
    {| ("Sample_buffer.create: capacity must be positive" (capacity 0)) |}];
  require_does_raise (fun () -> Sample_buffer.create ~capacity:(-1));
  [%expect
    {| ("Sample_buffer.create: capacity must be positive" (capacity -1)) |}]
;;

let%expect_test "empty buffer: no latest_seq, no samples" =
  let buffer = Sample_buffer.create ~capacity:3 in
  print_s [%sexp (Sample_buffer.latest_seq buffer : int option)];
  [%expect {| () |}];
  show_seqs (Sample_buffer.samples_after buffer ~after_seq:None);
  [%expect {| () |}];
  show_seqs (Sample_buffer.samples_after buffer ~after_seq:(Some 7));
  [%expect {| () |}]
;;

let%expect_test "overflowing the capacity drops the oldest samples" =
  let buffer = add_seqs (Sample_buffer.create ~capacity:3) [ 1; 2; 3 ] in
  show_seqs (Sample_buffer.samples_after buffer ~after_seq:None);
  [%expect {| (1 2 3) |}];
  (* Two more pushes evict 1 and 2; the survivors stay oldest-first. *)
  let buffer = add_seqs buffer [ 4; 5 ] in
  show_seqs (Sample_buffer.samples_after buffer ~after_seq:None);
  [%expect {| (3 4 5) |}];
  print_s [%sexp (Sample_buffer.latest_seq buffer : int option)];
  [%expect {| (5) |}]
;;

let%expect_test "samples_after: cursor positions inside, below, and above \
                 the buffer"
  =
  (* Capacity 3 holding seqs 3..5 — seqs 1 and 2 have been evicted. *)
  let buffer =
    add_seqs (Sample_buffer.create ~capacity:3) [ 1; 2; 3; 4; 5 ]
  in
  (* No cursor: the client has no history, send everything. *)
  show_seqs (Sample_buffer.samples_after buffer ~after_seq:None);
  [%expect {| (3 4 5) |}];
  (* Mid-buffer cursor: only the strictly-newer suffix. *)
  show_seqs (Sample_buffer.samples_after buffer ~after_seq:(Some 4));
  [%expect {| (5) |}];
  (* Cursor at the newest sample: fully caught up, nothing to send. *)
  show_seqs (Sample_buffer.samples_after buffer ~after_seq:(Some 5));
  [%expect {| () |}];
  (* Cursor below everything buffered: the client fell more than a buffer's
     worth behind, so it gets the whole buffer (the gap at seqs 1-2 is simply
     lost). *)
  show_seqs (Sample_buffer.samples_after buffer ~after_seq:(Some 1));
  [%expect {| (3 4 5) |}];
  (* Cursor above the newest sample: the exchange restarted and its numbering
     regressed, so the client must resynchronize from the whole buffer rather
     than wait for seqs that will never come. *)
  show_seqs (Sample_buffer.samples_after buffer ~after_seq:(Some 99));
  [%expect {| (3 4 5) |}]
;;

let%expect_test "response pairs samples_after with latest_seq" =
  let show_response buffer ~after_seq =
    let { Recent_samples.Response.samples; latest_seq } =
      Sample_buffer.response buffer ~query:{ after_seq }
    in
    print_s
      [%message
        ""
          ~samples:
            (List.map samples ~f:(fun (sample : Exchange_stats.t) ->
               sample.seq)
             : int list)
          (latest_seq : int option)]
  in
  let empty = Sample_buffer.create ~capacity:3 in
  show_response empty ~after_seq:None;
  [%expect {|
    ((samples    ())
     (latest_seq ()))
    |}];
  let buffer = add_seqs empty [ 1; 2; 3 ] in
  show_response buffer ~after_seq:(Some 1);
  [%expect {| ((samples (2 3)) (latest_seq (3))) |}];
  (* A caught-up client still learns [latest_seq], confirming the empty batch
     means "nothing new" rather than "empty buffer". *)
  show_response buffer ~after_seq:(Some 3);
  [%expect {| ((samples ()) (latest_seq (3))) |}]
;;
