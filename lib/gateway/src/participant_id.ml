open! Core
open Jsip_types

module T = struct
  type t = int [@@deriving compare, equal, hash, sexp_of]
end

include T
include Comparable.Make_plain (T)
include Hashable.Make_plain (T)

module Registry = struct
  (* Ids are dense and append-only (the k-th distinct name gets id k), so id
     -> name is a growable array indexed by the id itself: O(1) reads,
     amortized O(1) growth, no hashing on the way back to a name. *)
  type t =
    { ids : int Participant.Table.t
    ; names : Participant.t Dynarray.t
    }

  let create () =
    { ids = Participant.Table.create (); names = Dynarray.create () }
  ;;

  let intern t participant =
    Hashtbl.find_or_add t.ids participant ~default:(fun () ->
      let id = Dynarray.length t.names in
      Dynarray.add_last t.names participant;
      id)
  ;;

  let find t participant = Hashtbl.find t.ids participant
  let name t id = Dynarray.get t.names id
end
