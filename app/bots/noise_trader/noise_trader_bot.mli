module Config : sig
  type t

  val create
    :  symbols:Symbol.t list
    -> size_per_level:int
    -> num_levels:int
    -> inventory_skew_cents_per_share:int
    -> half_spread_cents:int
    -> min_half_spread_cents:int
    -> max_spread_cents:int
    -> t
end

include Jsip_bot_runtime.Bot_runtime.Bot with module Config := Config
