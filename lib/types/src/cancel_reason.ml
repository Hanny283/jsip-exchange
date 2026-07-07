open! Core

type t =
  | Participant_requested
  | Ioc_remainder
  | End_of_day
  | Self_trade_prevention
[@@deriving
  sexp
  , bin_io
  , compare
  , equal
  , hash
  , string ~capitalize:"SCREAMING_SNAKE_CASE"]
