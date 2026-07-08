open! Core

module List_seq = struct
  (* Index 0 lives at the head; index [i] is the [i]th element. [set] at the
     current length appends by walking to the end with [@]; [set] in range
     rebuilds the list with the one element swapped. Both are O(n), which is
     the whole point of benchmarking this against the growable array. *)
  type t = int list ref

  let create () = ref []

  let set t ~key ~data =
    let len = List.length !t in
    if key < 0 || key > len
    then
      raise_s
        [%message "List_seq.set: index out of range" (key : int) (len : int)];
    if key = len
    then t := !t @ [ data ]
    else t := List.mapi !t ~f:(fun i x -> if i = key then data else x)
  ;;

  let get t key = List.nth !t key

  (* Drop index [key], shifting later elements down. [List.filteri] rebuilds
     the whole list, so this is O(n) at any index -- a list can't remove from
     the front any more cheaply than from the middle. *)
  let remove t key =
    if key >= 0 && key < List.length !t
    then t := List.filteri !t ~f:(fun i _ -> i <> key)
  ;;
end

module Dynarray_seq = struct
  (* A growable array: [get]/[set] in range are O(1) array indexing, and an
     append is amortized O(1) via the doubling [Dynarray] does under the
     hood. *)
  type t = int Dynarray.t

  let create () = Dynarray.create ()

  let set t ~key ~data =
    let len = Dynarray.length t in
    if key = len
    then Dynarray.add_last t data
    else if key >= 0 && key < len
    then Dynarray.set t key data
    else
      raise_s
        [%message
          "Dynarray_seq.set: index out of range" (key : int) (len : int)]
  ;;

  let get t key =
    if key >= 0 && key < Dynarray.length t
    then Some (Dynarray.get t key)
    else None
  ;;

  (* Shift each later element one slot down over the removed index, then drop
     the now-duplicated last slot. Removing near the end copies almost
     nothing; removing from the front copies the whole tail, so this is O(n)
     in the distance from the end. *)
  let remove t key =
    let len = Dynarray.length t in
    if key >= 0 && key < len
    then (
      for i = key to len - 2 do
        Dynarray.set t i (Dynarray.get t (i + 1))
      done;
      Dynarray.remove_last t)
  ;;
end
