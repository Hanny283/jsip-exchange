open! Core
module Scenario_control = Jsip_dashboard_protocol.Scenario_control
module Category = Scenario_control.Category
module Scenario_info = Scenario_control.Scenario_info

let all : Scenario_info.t list =
  [ { name = "calm-day"
    ; blurb =
        "Quiet single-symbol AAPL market: one market maker and one slow \
         noise trader, no news. The benign baseline."
    ; expected =
        [ "Memory: flat - small resting book, nothing accumulates."
        ; "Submit & cancel latency: low and stable, tiny p99."
        ; "Pipe occupancy: request queue near 0; all subscriber pipes near \
           0."
        ; "Per-participant: market-maker holds a steady ~10-per-side \
           ladder; noise-trader trickles, ~0 cancels/sec."
        ; "Book depth (AAPL): tight stable BBO, order count in the low tens \
           per side."
        ; "Matching loop: low iterations/sec, tiny gaps."
        ]
    ; category = Baseline
    }
  ; { name = "active-day"
    ; blurb =
        "Three symbols (AAPL/GOOG/MSFT), a market maker each plus one \
         high-throughput noise trader on 100ms ticks. Busy but healthy."
    ; expected =
        [ "Memory: modestly higher but stable (three books)."
        ; "Submit latency: low-moderate and stable; cancel latency light."
        ; "Pipe occupancy: request queue near 0; market-data pipes present \
           per symbol but drained."
        ; "Per-participant: three market-maker rows plus one busy \
           noise-trader (~9 orders/sec, ~0 cancels)."
        ; "Book depth: healthy two-sided depth - use the symbol dropdown, \
           this is the only multi-symbol scenario."
        ; "Matching loop: higher iterations/sec than calm-day, still small \
           gaps."
        ]
    ; category = Baseline
    }
  ; { name = "earnings-shock"
    ; blurb =
        "A single +$5.00 news shock around t=15s. The market maker gets run \
         over; the momentum trader chases the move."
    ; expected =
        [ "Book depth (AAPL): a clear step at ~15s - BBO jumps ~+$5.00, \
           stale asks get swept then re-seed higher."
        ; "Per-participant: momentum-trader orders/sec spikes just after \
           the shock."
        ; "Memory and request queue: flat and benign throughout."
        ; "Submit/cancel latency: low; a brief activity bump, no queue \
           pressure."
        ; "Matching loop: small transient bump in iterations/sec around the \
           shock."
        ]
    ; category = Market_event
    }
  ; { name = "flash-crash"
    ; blurb =
        "Five -$3.00 shocks two seconds apart plus a 90%-sell marketable \
         whale. Two tight-spread market makers pull quotes as liquidity \
         collapses."
    ; expected =
        [ "Book depth (AAPL): dramatic - BBO steps down repeatedly; the \
           quoting side's order count and total size collapse toward zero \
           as both makers stand aside."
        ; "Per-participant: whale high orders/sec, ~0 resting; both \
           market-makers' resting_orders drop to 0 when they withdraw."
        ; "Memory: roughly flat (the whale is Ioc - nothing rests)."
        ; "Submit latency: moderate bumps during whale bursts, not \
           queue-pinned."
        ; "Matching loop: elevated iterations/sec during the cascade."
        ]
    ; category = Market_event
    }
  ; { name = "cancel-storm"
    ; blurb =
        "Three bots each run ~25 submit-then-cancel cycles every 100ms \
         (~750 submits/s + 750 cancels/s total), hammering the shared \
         request queue, against a market maker and noise trader."
    ; expected =
        [ "Cancel latency: the headline - p50/p90/p99 all elevated as \
           cancels flood the shared request pipe."
        ; "Submit latency: also elevated - submits and cancels share one \
           queue."
        ; "Pipe occupancy: request queue notably nonzero, can approach the \
           1024 budget under burst."
        ; "Per-participant: three Cancel Storm rows with very high \
           cancels/sec close to orders/sec and resting_orders near 0 - the \
           distinguishing shape."
        ; "Memory: flat (nothing accumulates)."
        ; "Matching loop: very high iterations/sec (every submit and cancel \
           is one iteration), small gaps."
        ]
    ; category = Pathological
    }
  ; { name = "book-filler"
    ; blurb =
        "One bot floods AAPL with ~500 resting Day orders/sec on fresh \
         price levels far from fair, never filling and never cancelling. No \
         market maker."
    ; expected =
        [ "Memory: clean linear, unbounded growth - the textbook \
           heap-growth pane (~500 live orders/sec retained forever)."
        ; "Book depth (AAPL): total size and order count climb without \
           bound on both sides (~+250/s per side); BBO stays pinned near \
           fair."
        ; "Submit latency: p99 rises over time as the book deepens and each \
           insert and scan costs more."
        ; "Per-participant: a single BookFiller row, high orders/sec, \
           resting_orders growing linearly, 0 cancels/sec."
        ; "Pipe occupancy: request queue low to moderate (500/s is under \
           the drain rate)."
        ; "Matching loop: steady ~500 iterations/sec, gaps growing slowly."
        ]
    ; category = Pathological
    }
  ; { name = "spam-storm"
    ; blurb =
        "Four specialized spammers each attacking a different resource - \
         fan-out, deep-sweep, book-bloat, and a 400-orders-per-2ms queue \
         flood - plus organic market maker, noise, and momentum activity. \
         The everything-at-once scenario."
    ; expected =
        [ "Pipe occupancy: request queue pinned at or near the 1024 budget \
           - intake outruns the single matching loop."
        ; "Submit latency: p99 blows out - with the queue full, each \
           submit's measured time includes long queue-wait."
        ; "Memory: grows (book-bloat's resting Day orders accumulate \
           unbounded)."
        ; "Book depth (AAPL): ask and bid order count and total size climb \
           while the touch churns; BBO jittery."
        ; "Per-participant: four spammer rows - book-bloat's resting_orders \
           grow; the others high orders/sec, ~0 resting."
        ; "Matching loop: iterations/sec maxed; gap p99 elevated \
           (deep-sweep's long match walks stall the loop)."
        ]
    ; category = Pathological
    }
  ; { name = "momentum-day"
    ; blurb =
        "A scripted staircase - six +$0.40 steps then six -$0.40 steps, \
         three seconds apart - that the momentum trader chases. Market \
         maker and noise trader for organic flow."
    ; expected =
        [ "Book depth (AAPL): BBO traces a clean up-then-down ramp \
           following the staircase; depth stays healthy."
        ; "Per-participant: momentum-trader orders/sec pulses on each \
           threshold crossing (buys up, sells down)."
        ; "Memory, latency, and queue: flat and stable throughout."
        ; "Matching loop: modest and stable."
        ]
    ; category = Market_event
    }
  ; { name = "quote-stuff"
    ; blurb =
        "A quote-stuffer floods ~800 one-share Day orders/sec one tick \
         inside a market maker's BBO on a frozen (zero-volatility) $150 \
         market. Never cancels."
    ; expected =
        [ "Matching loop: high iterations/sec (the stuffer dominates), \
           small gaps."
        ; "Submit latency: elevated from the ~800 orders/s stream; cancel \
           latency light (only the quoter's 1s re-quote)."
        ; "Per-participant: Stuffer very high orders/sec, 0 cancels; Quoter \
           ~10 orders/sec plus ~10 cancels/sec."
        ; "Book depth (AAPL): BBO pinned at $150.00; the stuffer packs the \
           top-of-book so order count climbs while total size grows only \
           slowly (one-share orders)."
        ; "Memory: grows to the extent the tiny orders rest - watch whether \
           it ramps linearly or plateaus and compare."
        ]
    ; category = Pathological
    }
  ; { name = "pump-and-dump"
    ; blurb =
        "A pump-and-dump bot walks the price up on marketable Ioc clips \
         then dumps into the momentum trader that chased it; a \
         fundamental-anchored market maker mostly refuses the bait."
    ; expected =
        [ "Book depth (AAPL): BBO ramps up during the pump then falls back \
           during the dump - a round-trip hump; the maker ladder stays \
           anchored near fair."
        ; "Per-participant: pump-and-dumper orders/sec pulses (buy clips \
           then sell clips), ~0 resting; momentum-trader chases up then is \
           left holding."
        ; "Memory and latency: flat and benign (clips are Ioc - nothing \
           rests)."
        ; "Matching loop: modest."
        ]
    ; category = Market_event
    }
  ; { name = "slow-consumer"
    ; blurb =
        "A market maker re-quotes 4 times/sec while two subscribers read \
         their market-data feed too slowly (2s and 5s per event), so events \
         pile up in the exchange-side buffer. The unbounded-buffering \
         pathology."
    ; expected =
        [ "Pipe occupancy: the market-data subscriber rows for the slow \
           consumers climb without bound (the 5s one fastest) - the one \
           scenario where a subscriber pipe grows unbounded. Watch the \
           trend arrows."
        ; "Memory: grows - the undrained buffered events are live heap; the \
           growth-rate tile goes positive."
        ; "Submit & cancel latency: low and stable - the matching loop and \
           request queue are unaffected by slow subscribers."
        ; "Per-participant: MarketMaker ~24 orders/sec plus ~24 \
           cancels/sec, small stable resting; slow consumers submit \
           nothing."
        ; "Book depth (AAPL): small stable maker ladder; BBO moves briskly."
        ; "Matching loop: steady, from maker churn only."
        ]
    ; category = Pathological
    }
  ]
;;

let is_known name =
  List.exists all ~f:(fun (info : Scenario_info.t) ->
    String.equal info.name name)
;;
