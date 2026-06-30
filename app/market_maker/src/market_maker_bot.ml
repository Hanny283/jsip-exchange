open! Core
open! Async
open Jsip_types
module Context = Jsip_bot_runtime.Bot_runtime.Context

module Config = struct
  type t =
    { inventory_counter : int Symbol.Table.t
    ; client_order_id_table : int Client_order_id.Table.t
    ; symbol : Symbol.t
    ; fair_value_cents : int
    ; half_spread_cents : int
    ; size_per_level : int
    ; num_levels : int
    ; inventory_skew_cents_per_share : int
    ; generator : Client_order_id.Generator.t
    }
end

let name = "Market_Maker"

let on_start (config : Config.t) (context : Context.t) =
  let inventory =
    Option.value
      (Hashtbl.find config.inventory_counter config.symbol)
      ~default:0
  in
  let skewed_fair =
    config.fair_value_cents
    - (inventory * config.inventory_skew_cents_per_share)
  in
  Deferred.List.iter
    ~how:`Parallel
    (List.init config.num_levels ~f:Fn.id)
    ~f:(fun level ->
      let offset = config.half_spread_cents + level in
      let%bind _ =
        Context.submit
          context
          ({ symbol = config.symbol
           ; participant = Context.participant context
           ; side = Buy
           ; price = Price.of_int_cents (skewed_fair - offset)
           ; size = Size.of_int config.size_per_level
           ; time_in_force = Day
           ; client_order_id =
               Client_order_id.Generator.next config.generator
           }
           : Order.Request.t)
      and _ =
        Context.submit
          context
          ({ symbol = config.symbol
           ; participant = Context.participant context
           ; side = Sell
           ; price = Price.of_int_cents (skewed_fair + offset)
           ; size = Size.of_int config.size_per_level
           ; time_in_force = Day
           ; client_order_id =
               Client_order_id.Generator.next config.generator
           }
           : Order.Request.t)
      in
      Deferred.unit)
;;

let on_tick (_config : Config.t) _contest = Deferred.unit

let on_event
  (config : Config.t)
  (context : Context.t)
  (event : Exchange_event.t)
  =
  match event with
  | Fill event ->
    let side, client_order_id =
      if Participant.( = )
           (Context.participant context)
           event.aggressor_participant
      then Side.sign event.aggressor_side, event.aggressor_client_order_id
      else
        ( Side.sign (Side.flip event.aggressor_side)
        , event.resting_client_order_id )
    in
    Hashtbl.update config.inventory_counter event.symbol ~f:(fun count ->
      match count with
      | Some count -> count + (side * Size.to_int event.size)
      | None -> side * Size.to_int event.size);
    let remaining_size =
      Hashtbl.update_and_return
        config.client_order_id_table
        client_order_id
        ~f:(fun remaining_size ->
          match remaining_size with
          | Some remaining_size -> remaining_size - Size.to_int event.size
          | None -> 0)
    in
    if remaining_size = 0
    then Hashtbl.remove config.client_order_id_table client_order_id;
    let keys_to_remove =
      Hashtbl.fold
        config.client_order_id_table
        ~init:[]
        ~f:(fun ~key:client_order_id ~data:_ acc -> client_order_id :: acc)
    in
    don't_wait_for
      (Deferred.List.iter
         ~how:`Sequential
         keys_to_remove
         ~f:(fun client_order_id ->
           Deferred.ignore_m (Context.cancel context client_order_id)));
    on_start config context
  | Order_cancel request ->
    Hashtbl.remove config.client_order_id_table request.client_order_id;
    Deferred.unit
  | Order_accept accepted ->
    Hashtbl.set
      config.client_order_id_table
      ~key:accepted.request.client_order_id
      ~data:(Size.to_int accepted.request.size);
    Deferred.unit
  | _ -> Deferred.unit
;;
