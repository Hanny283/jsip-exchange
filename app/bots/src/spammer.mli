open! Core
open! Async
open Jsip_types

(** A pathological exchange participant used to stress-test the exchange.

    On every tick it fires a tight burst of many orders, deliberately loading
    the server's bounded request queue, the dispatcher's per-event fan-out,
    and the (unbounded) subscriber pipes. It has no trading strategy and does
    not try to make money -- for a bot that manipulates prices for profit,
    see {!Pump_and_dump}, which started life as a second behavior of this
    module.

    A single scenario can run several independent instances by adding several
    [Bot_spec.t] entries: each entry sets that instance's participant name
    and RNG seed (both live on the spec, and the seeded RNG is reached
    through [Context.random]) and its own {!Config.t}, so instances tune
    independently -- e.g. one tuned to flood the request queue and another to
    bloat the book. *)
module Config : sig
  type t

  (** [create ~symbols ...] builds a spammer config. See the field comments
      in [spammer.ml] for what each knob controls: [orders_per_burst] is the
      core stress lever; [buy_chance], [marketable_chance], and
      [time_in_force_distribution] pick which downstream resource each order
      loads; [mean_size] and [price_jitter_cents] shape the orders
      themselves. *)
  val create
    :  symbols:Symbol_id.t list
    -> orders_per_burst:int
    -> buy_chance:Percent.t
    -> marketable_chance:Percent.t
    -> time_in_force_distribution:Time_in_force.t Bot_random.distribution
    -> mean_size:int
    -> price_jitter_cents:int
    -> t
end

include Jsip_bot_runtime.Bot_runtime.Bot with module Config := Config
