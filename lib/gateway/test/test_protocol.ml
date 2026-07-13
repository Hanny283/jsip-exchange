open! Core
open Jsip_types
open Jsip_order_book
open Jsip_gateway
open Jsip_test_harness

(* Command parsing now lives in [Exchange_command]; its tests have moved to
   [test_exchange_command.ml]. What remains here is event formatting, which
   is all [Protocol] still owns. *)

(* --- Event formatting --- *)

let%expect_test "format_event: all event types" =
  let events =
    [ Exchange_event.Order_accept
        { order_id = Order_id.of_string "1"
        ; participant = Participant.of_string "Alice"
        ; request =
            { symbol = Harness.aapl
            ; side = Buy
            ; price = Price.of_int_cents 15000
            ; size = Size.of_int 100
            ; time_in_force = Day
            ; client_order_id = Client_order_id.of_string "1"
            }
        }
    ; Fill
        { fill_id = 1
        ; symbol = Harness.aapl
        ; price = Price.of_int_cents 15000
        ; size = Size.of_int 100
        ; aggressor_order_id = Order_id.of_string "2"
        ; aggressor_participant = Participant.of_string "Alice"
        ; aggressor_side = Buy
        ; resting_order_id = Order_id.of_string "1"
        ; resting_participant = Participant.of_string "Bob"
        ; aggressor_client_order_id = Client_order_id.of_string "2"
        ; resting_client_order_id = Client_order_id.of_string "1"
        }
    ; Order_cancel
        { order_id = Order_id.of_string "3"
        ; participant = Participant.of_string "Charlie"
        ; symbol = Harness.tsla
        ; remaining_size = Size.of_int 50
        ; reason = Ioc_remainder
        ; client_order_id = Client_order_id.of_string "3"
        }
    ; Order_reject
        { participant = Participant.of_string "Alice"
        ; request =
            { symbol = Harness.goog
            ; side = Sell
            ; price = Price.of_int_cents 28000
            ; size = Size.of_int 10
            ; time_in_force = Day
            ; client_order_id = Client_order_id.of_string "4"
            }
        ; reason = "unknown symbol"
        }
    ; Best_bid_offer_update
        { symbol = Harness.aapl
        ; bbo =
            { bid =
                Some
                  { price = Price.of_int_cents 14990
                  ; size = Size.of_int 200
                  }
            ; ask =
                Some
                  { price = Price.of_int_cents 15010
                  ; size = Size.of_int 100
                  }
            }
        }
    ; Best_bid_offer_update { symbol = Harness.aapl; bbo = Bbo.empty }
    ; Trade_report
        { symbol = Harness.aapl
        ; price = Price.of_int_cents 15000
        ; size = Size.of_int 100
        }
    ]
  in
  List.iter events ~f:(fun e -> print_endline (Protocol.format_event e));
  [%expect
    {|
    ACCEPTED id=1 0 BUY 100@$150.00 DAY
    FILL fill_id=1 0 $150.00 x100 aggressor=2(Alice) client_id=2 BUY resting=1(Bob) client_id=1
    CANCELLED client_id=3 id=3 1 remaining=50 reason=IOC_REMAINDER
    REJECTED 2 SELL 10@$280.00 reason=unknown symbol
    BBO 0 bid=$149.90 x200 ask=$150.10 x100
    BBO 0 bid=- ask=-
    TRADE 0 $150.00 x100
    |}]
;;

(* --- Round-trip: parse then format --- *)

let%expect_test "round-trip: parse a command, submit, format result" =
  let open Jsip_test_harness in
  let t = Harness.create () in
  (* Place a resting sell *)
  Harness.submit_
    ~participant:Harness.bob
    t
    (Harness.sell ~price_cents:15000 ());
  (* Parse a buy command from text and submit it: the symbol token is the
     human name, resolved through the directory mirror at parse time — then
     the results render back through the same mirror. Name -> id -> engine ->
     id -> name. *)
  let symbols =
    Symbol_registry.of_symbols
      [ Symbol.of_string "AAPL"
      ; Symbol.of_string "TSLA"
      ; Symbol.of_string "GOOG"
      ]
  in
  let request =
    match Exchange_command.parse ~symbols "BUY 1 AAPL 100 150.00" with
    | Ok (Exchange_command.Submit request) -> request
    | Ok _ -> failwith "expected a Submit command"
    | Error err -> Error.raise err
  in
  let events =
    Matching_engine.submit
      (Harness.engine t)
      request
      ~participant:Harness.alice
  in
  print_endline (Protocol.format_events ~symbols events);
  [%expect
    {|
    ACCEPTED id=1 0 SELL 100@$150.00 DAY
    BBO 0 bid=- ask=$150.00 x100
    ACCEPTED id=2 AAPL BUY 100@$150.00 DAY
    FILL fill_id=1 AAPL $150.00 x100 aggressor=2(Alice) client_id=1 BUY resting=1(Bob) client_id=1
    TRADE AAPL $150.00 x100
    BBO AAPL bid=- ask=-
    |}]
;;
