module Exchange_command = struct
  type verb =
    | Buy
    | Sell
    | Book
    | Subscribe
  [@@deriving string]
end
