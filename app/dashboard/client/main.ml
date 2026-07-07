(* The browser entry point: js_of_ocaml runs this on page load, and
   [Start.start] mounts the dashboard on the element with id "app" (which the
   dashboard server's index page provides). *)

open! Core

let () = Bonsai_web.Start.start Jsip_dashboard_client.App.app
