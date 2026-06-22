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
  | symbol_str :: size_str :: price_str :: rest ->
    let open Result.Let_syntax in
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
        if List.mem
             Time_in_force.all
             (Time_in_force.of_string tif_str)
             ~equal:Time_in_force.equal
        then Ok (Time_in_force.of_string tif_str, rest')
        else
          Or_error.error_string
            [%string
              "unknown time-in-force: %{tif_str} %{Time_in_force.all_str}"]
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
  let command = String.split ~on:delimeter command in
  match command with
  | [] ->
    Or_error.error_string "Or_error.error_string: Received an empty string"
  | first_word :: rest_of_command ->
    let strip_rest = List.map rest_of_command ~f:String.strip in
    if String.is_empty (String.concat ~sep:" " strip_rest)
    then
      Or_error.error_string
        "Or_error.error_string: Command is missing arguments"
    else (
      let parts =
        String.split (String.concat ~sep:" " strip_rest) ~on:' '
        |> List.filter ~f:(Fn.non String.is_empty)
      in
      match Verb.of_string first_word with
      | Buy ->
        Or_error.map
          ~f:(fun element -> Submit element)
          (parse_buy_or_sell ?default_participant parts Buy)
      | Sell ->
        Or_error.map
          ~f:(fun element -> Submit element)
          (parse_buy_or_sell ?default_participant parts Sell)
      | Book ->
        Or_error.map
          ~f:(fun element -> Book element)
          (parse_book_or_subscribe parts)
      | Subscribe ->
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
