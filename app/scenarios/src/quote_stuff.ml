open! Core
open Jsip_types
open Jsip_scenario_runner

let name = "quote-stuff"

let description =
  "One quote-stuffer floods tiny orders one tick inside a market maker's \
   BBO."
;;

let symbol = Symbol.of_string "AAPL"

let oracle_config =
  Symbol.Map.of_alist_exn
    [ ( symbol
      , { Jsip_fundamental.Fundamental_oracle.Config.initial_price_cents =
            15000
        ; volatility_cents_per_sec = 0.0
        ; mean_reversion_strength = 0.0
        ; tick_interval = Time_ns.Span.of_sec 1.0
        } )
    ]
;;

(* A liquidity source: a five-level ladder straddling the fundamental (pinned
   at $150.00 by the zero-volatility oracle above), five cents wide at the
   tightest. Unlike a static quoter it cancels and re-posts every tick, but
   with a flat fundamental the prices don't move, so the stuffer still has a
   steady two-sided BBO to peg to. *)
let quoter =
  Bot_spec.T
    { bot = (module Jsip_bots.Market_maker_bot_lijia)
    ; config =
        Jsip_bots.Market_maker_bot_lijia.Config.create
          ~symbol
          ~half_spread_cents:5
          ~size_per_level:100
          ~num_levels:5
    ; participant = Participant.of_string "Quoter"
    ; symbols = [ symbol ]
    ; rng_seed = 1
    ; tick_interval = Time_ns.Span.of_sec 1.0
    ; is_marketdata_consumer = false
    }
;;

(* The pathology: 20 one-share orders per side every 50ms, forever, never
   cancelled. Must consume market data so it can see the BBO it stuffs. *)
let stuffer =
  Bot_spec.T
    { bot = (module Jsip_bots.Quote_stuffer)
    ; config =
        Jsip_bots.Quote_stuffer.Config.create
          ~symbols:[ symbol ]
          ~orders_per_burst:20
          ~order_size:(Size.of_int 1)
    ; participant = Participant.of_string "Stuffer"
    ; symbols = [ symbol ]
    ; rng_seed = 2
    ; tick_interval = Time_ns.Span.of_ms 50.
    ; is_marketdata_consumer = true
    }
;;

let configure () : Scenario_config.t =
  { name
  ; symbols = [ symbol ]
  ; oracle_config
  ; news = []
  ; bots = [ quoter; stuffer ]
  }
;;
