open! Core
open Jsip_types
open Jsip_gateway

(* Render the result of [Exchange_command.parse] for expect tests. [Submit]
   is printed via [Order.Request.to_string] so order-parsing cases read the
   same as the old [Protocol.parse_command] tests they were migrated from. *)
let print_parse line =
  match Exchange_command.parse line with
  | Error err -> print_endline [%string "ERROR: %{Error.to_string_hum err}"]
  | Ok (Exchange_command.Submit req) ->
    print_endline [%string "%{req#Order.Request}"]
  | Ok (Book symbol) -> print_endline [%string "BOOK %{symbol#Symbol_id}"]
  | Ok (Subscribe symbol) ->
    print_endline [%string "SUBSCRIBE %{symbol#Symbol_id}"]
  | Ok (Cancel client_order_id) ->
    print_endline [%string "CANCEL %{client_order_id#Client_order_id}"]
;;

(* --- BUY/SELL: successful parsing --- *)
(* The command grammar is
   [BUY|SELL <client_id> <symbol> <size> <price> [DAY|IOC]]. Identity comes
   from the login handshake, so the parsed request carries no participant at
   all. *)

let%expect_test "parse: basic buy" =
  print_parse "BUY 1 0 100 150.25";
  [%expect {| BUY 1 0 100@$150.25 DAY |}]
;;

let%expect_test "parse: basic sell" =
  print_parse "SELL 2 1 50 200.00";
  [%expect {| SELL 2 1 50@$200.00 DAY |}]
;;

let%expect_test "parse: case insensitive side" =
  print_parse "buy 1 0 100 150.00";
  print_parse "Buy 2 0 100 150.00";
  [%expect {|
    BUY 1 0 100@$150.00 DAY
    BUY 2 0 100@$150.00 DAY
    |}]
;;

let%expect_test "parse: with IOC time-in-force" =
  print_parse "BUY 1 0 100 150.00 IOC";
  [%expect {| BUY 1 0 100@$150.00 IOC |}]
;;

let%expect_test "parse: time-in-force is case insensitive" =
  print_parse "BUY 1 0 100 150.00 ioc";
  print_parse "SELL 2 0 200 151.00 day";
  [%expect
    {|
    BUY 1 0 100@$150.00 IOC
    SELL 2 0 200@$151.00 DAY
    |}]
;;

let%expect_test "parse: with explicit DAY" =
  print_parse "SELL 1 0 200 151.00 DAY";
  [%expect {| SELL 1 0 200@$151.00 DAY |}]
;;

let%expect_test "parse error: symbol token must be a non-negative id" =
  (* Phase-1 grammar: the symbol is typed as its raw integer id. Names come
     back with the directory in Phase 2. *)
  print_parse "BUY 1 AAPL 100 150.00";
  print_parse "BUY 1 -3 100 150.00";
  [%expect
    {|
    ERROR: invalid symbol id: AAPL
    exception: (Failure int_of_string)
    ERROR: invalid symbol id: -3
    exception: ("Symbol_id.of_int: id must be non-negative" (int -3))
    |}]
;;

let%expect_test "parse: extra whitespace is ignored" =
  print_parse "  BUY   1   0   100   150.00  ";
  [%expect {| BUY 1 0 100@$150.00 DAY |}]
;;

let%expect_test "parse: price with dollar sign" =
  print_parse "BUY 1 0 100 $150.25";
  [%expect {| BUY 1 0 100@$150.25 DAY |}]
;;

(* --- CANCEL --- *)

let%expect_test "parse: cancel by client order id" =
  print_parse "CANCEL 7";
  [%expect {| CANCEL 7 |}]
;;

let%expect_test "parse: cancel is case insensitive on the verb" =
  print_parse "cancel 7";
  print_parse "Cancel 8";
  [%expect {|
    CANCEL 7
    CANCEL 8
    |}]
;;

(* --- BOOK / SUBSCRIBE --- *)

let%expect_test "parse: book with symbol" =
  print_parse "BOOK 0";
  [%expect {| BOOK 0 |}]
;;

let%expect_test "parse: book is case insensitive on the verb" =
  print_parse "book 0";
  print_parse "Book 1";
  [%expect {|
    BOOK 0
    BOOK 1
    |}]
;;

let%expect_test "parse: subscribe with symbol" =
  print_parse "SUBSCRIBE 0";
  [%expect {| SUBSCRIBE 0 |}]
;;

let%expect_test "parse: subscribe is case insensitive on the verb" =
  print_parse "subscribe 0";
  print_parse "SuBsCrIbE 1";
  [%expect {|
    SUBSCRIBE 0
    SUBSCRIBE 1
    |}]
;;

(* --- Parse errors --- *)

let%expect_test "parse error: empty / whitespace only" =
  print_parse "";
  print_parse "   ";
  [%expect
    {|
    ERROR: command is missing arguments
    ERROR: command is missing arguments
    |}]
;;

let%expect_test "parse error: unknown command" =
  print_parse "HOLD 1 0 100 150.00";
  [%expect {| ERROR: unknown command: HOLD |}]
;;

let%expect_test "parse error: non-integer client order id" =
  print_parse "BUY abc 0 100 150.00";
  [%expect {| ERROR: Request must have client_order_id |}]
;;

let%expect_test "parse error: missing fields" =
  print_parse "BUY 1 0";
  print_parse "BUY";
  [%expect
    {|
    ERROR: expected: BUY|SELL <client_order_id> <symbol> <size> <price> [DAY or IOC]
    ERROR: command is missing arguments
    |}]
;;

let%expect_test "parse error: invalid size" =
  print_parse "BUY 1 0 abc 150.00";
  print_parse "BUY 1 0 0 150.00";
  print_parse "BUY 1 0 -5 150.00";
  [%expect
    {|
    ERROR: invalid size: abc
    ERROR: size must be positive
    ERROR: size must be positive
    |}]
;;

let%expect_test "parse error: invalid price" =
  print_parse "BUY 1 0 100 xyz";
  [%expect
    {|
    ERROR: invalid price: xyz
    exception: (Invalid_argument "Float.of_string xyz")
    |}]
;;

let%expect_test "parse error: unknown time-in-force" =
  print_parse "BUY 1 0 100 150.00 QQQ";
  [%expect {| ERROR: unknown time-in-force: QQQ (expected DAY or IOC) |}]
;;
