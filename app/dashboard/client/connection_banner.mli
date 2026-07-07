(** The sticky strip across the top of the dashboard: product name on the
    left, connection health on the right.

    The health chip mirrors {!Samples_subscription.Status}:

    - [Waiting] — muted dot, "connecting"; shown until the first poll
      answers.
    - [Connected] — mint dot, "live".
    - [Failing] — red dot, "disconnected", plus the error rendered inline
      (ellipsized to one line; hover for the full text). Panes below keep
      showing the last good window, so the banner is the one place a broken
      feed is unmissable. *)

open! Core
open Bonsai_web

(** [view status] renders the banner for the current connection state. *)
val view : Samples_subscription.Status.t -> Vdom.Node.t
