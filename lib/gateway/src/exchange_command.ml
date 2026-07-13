open! Core
open! Jsip_types

module Verb = struct
  type t =
    | Buy
    | Sell
    | Book
    | Subscribe
    | Cancel
  [@@deriving string ~case_insensitive ~capitalize:"SCREAMING_SNAKE_CASE"]
end

type t =
  | Submit of Order.Request.t
  | Book of Symbol_id.t
  | Subscribe of Symbol_id.t
  | Cancel of Client_order_id.t

(* Phase 2 grammar: the symbol token is the human NAME, resolved to its id
   through the consumer's directory mirror at parse time — this is the
   name->id edge. *)
let parse_symbol ~symbols symbol_str =
  match Symbol_registry.id symbols (Symbol.of_string symbol_str) with
  | Some id -> Ok id
  | None -> Or_error.error_string [%string "unknown symbol: %{symbol_str}"]
  | exception exn ->
    let exn_str = Exn.to_string exn in
    Or_error.error_string
      [%string "invalid symbol: %{symbol_str}\nexception: %{exn_str}"]
;;

let parse_book_or_subscribe ~symbols parts =
  match parts with
  | symbol_str :: _ ->
    let open Result.Let_syntax in
    let%bind symbol = parse_symbol ~symbols symbol_str in
    Ok symbol
  | [] -> Or_error.error_string "Bug: Impossible Case"
;;

let parse_cancel parts =
  match parts with
  | client_order_id_str :: _ ->
    let open Result.Let_syntax in
    let%bind client_order_id =
      try Ok (Client_order_id.of_string client_order_id_str) with
      | exn ->
        let exn_str = Exn.to_string exn in
        Or_error.error_string
          [%string
            "invalid client_order_id: %{client_order_id_str}\n\
             exception: %{exn_str}"]
    in
    Ok client_order_id
  | [] -> Or_error.error_string "Bug: Impossible Case"
;;

let parse_buy_or_sell ~symbols parts side =
  match parts with
  | client_order_id_str :: symbol_str :: size_str :: price_str :: rest ->
    let open Result.Let_syntax in
    let%bind client_order_id =
      match Int.of_string_opt client_order_id_str with
      | Some int ->
        ignore int;
        Ok (Client_order_id.of_string client_order_id_str)
      | None -> Or_error.error_string "Request must have client_order_id"
    in
    let%bind size =
      match Int.of_string_opt size_str with
      | Some n when n > 0 -> Ok n
      | Some _ -> Or_error.error_string "size must be positive"
      | None -> Or_error.error_string [%string "invalid size: %{size_str}"]
    in
    let%bind price =
      try Ok (Price.of_string price_str) with
      | exn ->
        let exn_str = Exn.to_string exn in
        Or_error.error_string
          [%string "invalid price: %{price_str}\nexception: %{exn_str}"]
    in
    let%bind symbol = parse_symbol ~symbols symbol_str in
    let%bind time_in_force, rest =
      match rest with
      | tif_str :: rest' ->
        (match
           Or_error.try_with (fun () -> Time_in_force.of_string tif_str)
         with
         | Ok tif -> Ok (tif, rest')
         | Error _ ->
           Or_error.error_string
             [%string
               "unknown time-in-force: %{tif_str} (expected \
                %{Time_in_force.all_str})"])
      | [] -> Ok (Day, [])
    in
    (* Identity now comes from the login handshake, so the order text no
       longer carries a participant; anything left after the time-in-force is
       an error rather than an "as <name>" clause. *)
    let%bind () =
      match rest with
      | [] -> Ok ()
      | _ ->
        let trailing = String.concat ~sep:" " rest in
        Or_error.error_string
          [%string "unexpected trailing arguments: %{trailing}"]
    in
    Ok
      ({ symbol
       ; side
       ; price
       ; size = Size.of_int size
       ; time_in_force
       ; client_order_id
       }
       : Order.Request.t)
  | _ ->
    Or_error.error_string
      ("expected: BUY|SELL <client_order_id> <symbol> <size> <price> "
       ^ "["
       ^ Time_in_force.all_str
       ^ "]")
;;

let parse ~symbols command =
  let delimeter = ' ' in
  let command = String.split ~on:delimeter (String.strip command) in
  match command with
  | [] -> Or_error.error_string "empty command"
  | first_word :: rest_of_command ->
    let strip_rest = List.map rest_of_command ~f:String.strip in
    if String.is_empty (String.concat ~sep:" " strip_rest)
    then Or_error.error_string "command is missing arguments"
    else (
      let parts =
        String.split (String.concat ~sep:" " strip_rest) ~on:' '
        |> List.filter ~f:(Fn.non String.is_empty)
      in
      match Or_error.try_with (fun () -> Verb.of_string first_word) with
      | Error _ ->
        Or_error.error_string [%string "unknown command: %{first_word}"]
      | Ok Buy ->
        Or_error.map
          ~f:(fun element -> Submit element)
          (parse_buy_or_sell ~symbols parts Buy)
      | Ok Sell ->
        Or_error.map
          ~f:(fun element -> Submit element)
          (parse_buy_or_sell ~symbols parts Sell)
      | Ok Book ->
        Or_error.map
          ~f:(fun element -> Book element)
          (parse_book_or_subscribe ~symbols parts)
      | Ok Subscribe ->
        Or_error.map
          ~f:(fun element -> Subscribe element)
          (parse_book_or_subscribe ~symbols parts)
      | Ok Cancel ->
        Or_error.map ~f:(fun element -> Cancel element) (parse_cancel parts))
;;
