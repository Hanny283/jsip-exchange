open! Core
open Jsip_types
open Jsip_gateway

(* Render the result of [Exchange_command.parse] for expect tests. [Submit] is
   printed via [Order.Request.to_string] so order-parsing cases read the same
   as the old [Protocol.parse_command] tests they were migrated from. *)
let print_parse ?default_participant line =
  match Exchange_command.parse ?default_participant line with
  | Error err -> print_endline [%string "ERROR: %{Error.to_string_hum err}"]
  | Ok (Exchange_command.Submit req) ->
    print_endline [%string "%{req#Order.Request}"]
  | Ok (Book symbol) -> print_endline [%string "BOOK %{symbol#Symbol}"]
  | Ok (Subscribe symbol) -> print_endline [%string "SUBSCRIBE %{symbol#Symbol}"]
;;

(* --- BUY/SELL: successful parsing --- *)

let%expect_test "parse: basic buy" =
  print_parse "BUY AAPL 100 150.25";
  [%expect {| BUY AAPL 100@$150.25 DAY as anonymous |}]
;;

let%expect_test "parse: basic sell" =
  print_parse "SELL TSLA 50 200.00";
  [%expect {| SELL TSLA 50@$200.00 DAY as anonymous |}]
;;

let%expect_test "parse: case insensitive side" =
  print_parse "buy AAPL 100 150.00";
  print_parse "Buy AAPL 100 150.00";
  [%expect
    {|
    BUY AAPL 100@$150.00 DAY as anonymous
    BUY AAPL 100@$150.00 DAY as anonymous
    |}]
;;

let%expect_test "parse: with IOC time-in-force" =
  print_parse "BUY AAPL 100 150.00 IOC";
  [%expect {| BUY AAPL 100@$150.00 IOC as anonymous |}]
;;

let%expect_test "parse: time-in-force is case insensitive" =
  print_parse "BUY AAPL 100 150.00 ioc";
  print_parse "SELL AAPL 200 151.00 day";
  [%expect
    {|
    BUY AAPL 100@$150.00 IOC as anonymous
    SELL AAPL 200@$151.00 DAY as anonymous
    |}]
;;

let%expect_test "parse: with explicit DAY" =
  print_parse "SELL AAPL 200 151.00 DAY";
  [%expect {| SELL AAPL 200@$151.00 DAY as anonymous |}]
;;

let%expect_test "parse: with participant" =
  print_parse "BUY AAPL 100 150.00 as Alice";
  [%expect {| BUY AAPL 100@$150.00 DAY as Alice |}]
;;

let%expect_test "parse: with TIF and participant" =
  print_parse "SELL GOOG 75 2800.50 IOC as Bob";
  [%expect {| SELL GOOG 75@$2800.50 IOC as Bob |}]
;;

let%expect_test "parse: symbol case is preserved" =
  print_parse "BUY aapl 100 150.00";
  [%expect {| BUY aapl 100@$150.00 DAY as anonymous |}]
;;

let%expect_test "parse: extra whitespace is ignored" =
  print_parse "  BUY   AAPL   100   150.00  ";
  [%expect {| BUY AAPL 100@$150.00 DAY as anonymous |}]
;;

let%expect_test "parse: price with dollar sign" =
  print_parse "BUY AAPL 100 $150.25";
  [%expect {| BUY AAPL 100@$150.25 DAY as anonymous |}]
;;

(* --- BOOK / SUBSCRIBE --- *)

let%expect_test "parse: book with symbol" =
  print_parse "BOOK AAPL";
  [%expect {| BOOK AAPL |}]
;;

let%expect_test "parse: book is case insensitive on the verb" =
  print_parse "book AAPL";
  print_parse "Book TSLA";
  [%expect
    {|
    BOOK AAPL
    BOOK TSLA
    |}]
;;

let%expect_test "parse: subscribe with symbol" =
  print_parse "SUBSCRIBE AAPL";
  [%expect {| SUBSCRIBE AAPL |}]
;;

let%expect_test "parse: subscribe is case insensitive on the verb" =
  print_parse "subscribe AAPL";
  print_parse "SuBsCrIbE TSLA";
  [%expect
    {|
    SUBSCRIBE AAPL
    SUBSCRIBE TSLA
    |}]
;;

(* --- default participant override --- *)

let%expect_test "default participant: used when no 'as' clause is given" =
  let default_participant = Participant.of_string "DefaultTrader" in
  print_parse ~default_participant "BUY AAPL 100 150.00";
  [%expect {| BUY AAPL 100@$150.00 DAY as DefaultTrader |}]
;;

let%expect_test "default participant: explicit 'as' clause wins" =
  let default_participant = Participant.of_string "DefaultTrader" in
  print_parse ~default_participant "BUY AAPL 100 150.00 as Alice";
  [%expect {| BUY AAPL 100@$150.00 DAY as Alice |}]
;;

let%expect_test "default participant: applies with an explicit TIF too" =
  let default_participant = Participant.of_string "DefaultTrader" in
  print_parse ~default_participant "SELL AAPL 50 151.00 IOC";
  [%expect {| SELL AAPL 50@$151.00 IOC as DefaultTrader |}]
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
  print_parse "HOLD AAPL 100 150.00";
  [%expect {| ERROR: unknown command: HOLD |}]
;;

let%expect_test "parse error: missing fields" =
  print_parse "BUY AAPL";
  print_parse "BUY";
  [%expect
    {|
    ERROR: expected: BUY|SELL <symbol> <size> <price> [DAY or IOC] [as <name>]
    ERROR: command is missing arguments
    |}]
;;

let%expect_test "parse error: invalid size" =
  print_parse "BUY AAPL abc 150.00";
  print_parse "BUY AAPL 0 150.00";
  print_parse "BUY AAPL -5 150.00";
  [%expect
    {|
    ERROR: invalid size: abc
    ERROR: size must be positive
    ERROR: size must be positive
    |}]
;;

let%expect_test "parse error: invalid price" =
  print_parse "BUY AAPL 100 xyz";
  [%expect
    {|
    ERROR: invalid price: xyz
    exception: (Invalid_argument "Float.of_string xyz")
    |}]
;;

let%expect_test "parse error: unknown time-in-force" =
  print_parse "BUY AAPL 100 150.00 QQQ";
  [%expect {| ERROR: unknown time-in-force: QQQ (expected DAY or IOC) |}]
;;
