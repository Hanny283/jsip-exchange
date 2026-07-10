open! Core

module T = struct
  type t = int [@@deriving sexp, bin_io, compare, equal, hash, string]
end

include T
include Comparable.Make (T)
include Hashable.Make (T)

let of_int int =
  if int < 0
  then
    raise_s
      [%message "Symbol_id.of_int: id must be non-negative" (int : int)];
  int
;;

let to_int t = t

(* Route the textual entry points through [of_int] so a negative id can't
   sneak in via parsed input. [bin_io] deliberately stays unvalidated: it is
   a machine format, and the server bounds-checks every id before indexing
   anyway. *)
let of_string string = of_int (T.of_string string)
let t_of_sexp sexp = of_int (T.t_of_sexp sexp)
