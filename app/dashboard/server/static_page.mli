(** The one HTML page the dashboard serves.

    {!Web_server} returns {!index_html} for [GET /]; the page loads the
    js_of_ocaml client bundle from [/main.bc.js], which mounts the Bonsai app
    on the [<div id="app">] element. *)

open! Core
open! Async

(** The dashboard's index page. The [<script>] tag carries [defer] so the
    bundle runs only after the document — including the [#app] mount point
    that [Bonsai_web.Start.start] looks for — has been parsed. *)
val index_html : string
