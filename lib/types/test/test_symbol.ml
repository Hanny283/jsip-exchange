open! Core
open Jsip_types
open Expect_test_helpers_core

let%expect_test "of_string: empty string raises" =
  require_does_raise (fun () -> Symbol.of_string "");
  [%expect {| "Symbol.of_string: symbol must be non-empty" |}]
;;

let%expect_test "Symbol_id: negative ids are rejected at every text entry \
                 point"
  =
  require_does_raise (fun () -> Symbol_id.of_int (-1));
  [%expect {| ("Symbol_id.of_int: id must be non-negative" (int -1)) |}];
  require_does_raise (fun () -> Symbol_id.of_string "-7");
  [%expect {| ("Symbol_id.of_int: id must be non-negative" (int -7)) |}];
  require_does_raise (fun () ->
    ignore ([%of_sexp: Symbol_id.t] (Sexp.of_string "-3") : Symbol_id.t));
  [%expect {| ("Symbol_id.of_int: id must be non-negative" (int -3)) |}]
;;

let%expect_test "Symbol_id: round-trips" =
  let id = Symbol_id.of_int 7 in
  print_s
    [%message
      (id : Symbol_id.t)
        ~as_string:(Symbol_id.to_string id : string)
        ~as_int:(Symbol_id.to_int id : int)];
  [%expect
    {|
    ((id        7)
     (as_string 7)
     (as_int    7))
    |}]
;;
