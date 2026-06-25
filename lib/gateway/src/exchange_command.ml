open! Core
open! Jsip_types

module Verb = struct
  type t =
    | Buy
    | Sell
    | Book
    | Subscribe
  [@@deriving string ~case_insensitive ~capitalize:"SCREAMING_SNAKE_CASE"]
end

type t =
  | Submit of Order.Request.t
  | Book of Symbol.t
  | Subscribe of Symbol.t

let parse_book_or_subscribe parts =
  match parts with
  | symbol_str :: _ ->
    let open Result.Let_syntax in
    let%bind symbol =
      try Ok (Symbol.of_string symbol_str) with
      | exn ->
        let exn_str = Exn.to_string exn in
        Or_error.error_string
          [%string "invalid symbol: %{symbol_str}\nexception: %{exn_str}"]
    in
    Ok symbol
  | [] -> Or_error.error_string "Bug: Impossible Case"
;;

let parse_buy_or_sell ?default_participant parts side =
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
    let%bind symbol =
      try Ok (Symbol.of_string symbol_str) with
      | exn ->
        let exn_str = Exn.to_string exn in
        Or_error.error_string
          [%string "invalid symbol: %{symbol_str}\nexception: %{exn_str}"]
    in
    let%bind time_in_force, rest =
      match rest with
      | tif_str :: rest' ->
        (match
           Or_error.try_with (fun () -> Time_in_force.of_string tif_str)
         with
         | Ok tif -> Ok (tif, rest')
         | Error _ ->
           (* Not a time-in-force. If it's the start of an "as <name>"
              clause, fall through to the default Day and leave the clause
              for the participant parser; otherwise it's a genuine error. *)
           (match tif_str with
            | "as" | "AS" -> Ok (Day, rest)
            | _ ->
              Or_error.error_string
                [%string
                  "unknown time-in-force: %{tif_str} (expected \
                   %{Time_in_force.all_str})"]))
      | [] -> Ok (Day, [])
    in
    let%bind participant =
      match rest with
      | "as" :: name :: _ | "AS" :: name :: _ ->
        Ok (Participant.of_string name)
      | [] ->
        (match default_participant with
         | Some participant -> Ok participant
         | None -> Ok (Participant.of_string "anonymous"))
      | _ ->
        let trailing = String.concat ~sep:" " rest in
        Or_error.error_string
          [%string "unexpected trailing arguments: %{trailing}"]
    in
    Ok
      ({ symbol
       ; participant
       ; side
       ; price
       ; size = Size.of_int size
       ; time_in_force
       ; client_order_id
       }
       : Order.Request.t)
  | _ ->
    Or_error.error_string
      ("expected: BUY|SELL <symbol> <size> <price> "
       ^ "["
       ^ Time_in_force.all_str
       ^ "]"
       ^ " [as <name>]")
;;

let parse ?default_participant command =
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
          (parse_buy_or_sell ?default_participant parts Buy)
      | Ok Sell ->
        Or_error.map
          ~f:(fun element -> Submit element)
          (parse_buy_or_sell ?default_participant parts Sell)
      | Ok Book ->
        Or_error.map
          ~f:(fun element -> Book element)
          (parse_book_or_subscribe parts)
      | Ok Subscribe ->
        Or_error.map
          ~f:(fun element -> Subscribe element)
          (parse_book_or_subscribe parts))
;;

(* let parse_command line = let line = String.strip line in if
   String.is_empty line then Or_error.error_string"empty command" else ( let
   parts = String.split line ~on:' ' |> List.filter ~f:(Fn.non
   String.is_empty) in match parts with | [] -> Or_error.error_string"empty
   command" | side_str :: rest -> let open Result.Let_syntax in let%bind side
   = match String.uppercase side_str with | "BUY" -> Ok Side.Buy | "SELL" ->
   Ok Side.Sell | other ->
   Or_error.error_string[%string "unknown command: %{other} (expected BUY or SELL)"]
   in (match rest with | symbol_str :: size_str :: price_str :: rest ->
   let%bind size = match Int.of_string_opt size_str with | Some n when n > 0
   -> Ok n | Some _ -> Or_error.error_string"size must be positive" | None ->
   Or_error.error_string[%string "invalid size: %{size_str}"] in let%bind
   price = try Ok (Price.of_string price_str) with | exn -> let exn_str =
   Exn.to_string exn in Or_error.error_string
   [%string "invalid price: %{price_str}\nexception: %{exn_str}"] in let%bind
   symbol = try Ok (Symbol.of_string symbol_str) with | exn -> let exn_str =
   Exn.to_string exn in Or_error.error_string
   [%string "invalid symbol: %{symbol_str}\nexception: %{exn_str}"] in
   let%bind time_in_force, rest = match rest with | tif_str :: rest' -> if
   List.mem (Time_in_force.of_string tif_str) Time_in_force.all then Ok
   (Time_in_force.of_string tif_str, rest') else Or_error.error_string
   [%string "unknown time-in-force: %{tif_str} %{Time_in_force.all_str}"]) |
   [] -> Ok (Day, []) in let%bind participant = match rest with | "as" ::
   name :: _ | "AS" :: name :: _ -> Ok (Participant.of_string name) | [] ->
   Ok default_participant | _ -> let trailing = String.concat ~sep:" " rest
   in
   Or_error.error_string[%string "unexpected trailing arguments: %{trailing}"]
   in Ok
   ([{ symbol ; participant ; side ; price ; size = Size.of_int size ; time_in_force }]
   : Order.Request.t) | _ -> Or_error.error_string "expected: BUY|SELL
   <symbol> <size> <price> [DAY|IOC] [as <name>]") ;; *)
