(** The whole dashboard, assembled: one {!Samples_subscription} feeding seven
    panes in a responsive grid under a {!Connection_banner}.

    Pane order puts what an operator checks first top-left: submit and cancel
    latency, then matching-loop cadence, pipe occupancy, GC pressure,
    participant activity, and book depth. Every pane derives its view record
    as a separate cutoff [Bonsai.t], so a second-by- second window update
    re-renders only the panes whose numbers moved.

    [Main] passes {!app} to [Bonsai_web.Start.start]; nothing else should
    need this module. *)

open! Core
open Bonsai_web

(** [app graph] builds the dashboard's root component. *)
val app : local_ Bonsai.graph -> Vdom.Node.t Bonsai.t
