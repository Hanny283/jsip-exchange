open! Core
open Jsip_types

type t =
  { names : Symbol.t array (* index = id *)
  ; ids : Symbol_id.t Symbol.Table.t
  }

let of_symbols symbols =
  let names = Array.of_list symbols in
  let ids = Symbol.Table.create () in
  Array.iteri names ~f:(fun id name ->
    Hashtbl.add_exn ids ~key:name ~data:(Symbol_id.of_int id));
  { names; ids }
;;

let num_symbols t = Array.length t.names

let to_directory t =
  Hashtbl.to_alist t.ids
  |> List.sort ~compare:(fun (_, id1) (_, id2) -> Symbol_id.compare id1 id2)
;;

let of_directory directory =
  (* The wire contract doesn't bake in density, so check it here: ids must be
     exactly [0 .. n - 1] with distinct names, or the mirror would disagree
     with the server about what an id means. *)
  let sorted =
    List.sort directory ~compare:(fun (_, id1) (_, id2) ->
      Symbol_id.compare id1 id2)
  in
  let dense =
    List.for_alli sorted ~f:(fun i ((_ : Symbol.t), id) ->
      Symbol_id.to_int id = i)
  in
  if not dense
  then
    Or_error.error_s
      [%message
        "Symbol_registry.of_directory: ids are not dense 0..n-1"
          (directory : (Symbol.t * Symbol_id.t) list)]
  else
    Or_error.try_with (fun () ->
      of_symbols (List.map sorted ~f:(fun (name, _) -> name)))
;;

let id t name = Hashtbl.find t.ids name

let name t id =
  let i = Symbol_id.to_int id in
  if i >= 0 && i < Array.length t.names then Some t.names.(i) else None
;;
