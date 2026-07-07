(** A command-latency pane: percentiles plus a bucketed histogram.

    Used twice on the dashboard — once for order submissions and once for
    cancels — over the corresponding {!Dashboard_state.Latency_view}
    (histograms merged across the whole window):

    {[
      Latency_pane.view ~title:"submit latency" submit_view;
      Latency_pane.view ~title:"cancel latency" cancel_view
    ]}

    p50/p90/p99 render as {!Stat_tile}s (em-dash until there are
    observations); the bucket distribution renders as {!Histogram_bars},
    whose fixed height keeps the pane from jumping while the window fills or
    drains. *)

open! Core
open Bonsai_web

(** [view ~title latency] renders one latency pane titled [title]. *)
val view : title:string -> Dashboard_state.Latency_view.t -> Vdom.Node.t
