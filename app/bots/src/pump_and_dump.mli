open! Core
open! Async
open Jsip_types

(** A market-manipulation bot running a stateful two-phase pump-and-dump on a
    single symbol.

    It fires marketable buys to walk the price up ([Accumulate]), and once
    the observed mid has risen a target fraction it flips and sells its
    inventory into the bids left by anyone who chased the move
    ([Distribute]). It profits only from price-chasers (e.g. a momentum
    trader), not from a fundamental-anchored market maker -- and it decides
    when to dump purely from observed prices, never the oracle.

    This bot began life as a [behavior] of {!Spammer} and was split out: the
    spammer is a strategy-free resource flood, while this bot carries real
    trading state (phase, position, P&L). See
    [app/scenarios/src/pump_and_dump.ml] for a scenario that pits it against
    its intended victim.

    A single scenario can run several independent instances by adding several
    [Bot_spec.t] entries: each entry sets that instance's participant name
    and RNG seed (both live on the spec, and the seeded RNG is reached
    through [Context.random]) and its own {!Config.t}, so instances tune
    independently. *)

(** Phases of the scheme. State advances [Accumulate -> Distribute -> Done]
    and never moves backward. *)
module Phase : sig
  type t =
    | Accumulate
    | Distribute
    | Done
  [@@deriving sexp_of]
end

module Config : sig
  type t

  (** [create ~target_symbol ...] builds a config with the scheme's state
      seeded to a fresh run ([Accumulate], flat position, no price anchor).
      See the field comments in [pump_and_dump.ml] for what each knob
      controls. *)
  val create
    :  target_symbol:Symbol.t
    -> pump_target_pct:Percent.t
    -> clip_size:int
    -> max_inventory:int
    -> give_up_ticks:int
    -> aggression_offset_cents:int
    -> entry_time_in_force:Time_in_force.t
    -> t

  (** Read-only views of the scheme's running state, so tests can observe how
      a run progresses without the mutable fields being exposed. *)
  module For_testing : sig
    val phase : t -> Phase.t

    (** Signed shares held; long while accumulating. *)
    val position : t -> int

    (** Selling proceeds minus buying cost, in cents. *)
    val realized_pnl_cents : t -> int
  end
end

include Jsip_bot_runtime.Bot_runtime.Bot with module Config := Config
