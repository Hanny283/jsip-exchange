open! Core
open! Async
open Jsip_types
open Jsip_gateway

module Config = struct
  type t =
    { participant : Participant.t
    ; symbol : Symbol.t
    ; fair_value_cents : int
    ; half_spread_cents : int
    ; size_per_level : int
    ; num_levels : int
    ; inventory_skew_cents_per_share : int
    }
  [@@deriving sexp_of]
end

let generator = Client_order_id.Generator.create ()

let seed_book (config : Config.t) conn =
  let submit request =
    let%map result =
      Rpc.Rpc.dispatch_exn Rpc_protocol.submit_order_rpc conn request
    in
    match result with
    | Ok () -> ()
    | Error msg ->
      [%log.error
        "market_maker: submit failed"
          (request : Order.Request.t)
          (msg : Error.t)]
  in
  Deferred.List.iter
    ~how:`Parallel
    (List.init config.num_levels ~f:Fn.id)
    ~f:(fun level ->
      let offset = config.half_spread_cents + level in
      let%bind () =
        submit
          ({ symbol = config.symbol
           ; participant = config.participant
           ; side = Buy
           ; price = Price.of_int_cents (config.fair_value_cents - offset)
           ; size = Size.of_int config.size_per_level
           ; time_in_force = Day
           ; client_order_id = Client_order_id.Generator.next generator
           }
           : Order.Request.t)
      and () =
        submit
          ({ symbol = config.symbol
           ; participant = config.participant
           ; side = Sell
           ; price = Price.of_int_cents (config.fair_value_cents + offset)
           ; size = Size.of_int config.size_per_level
           ; time_in_force = Day
           ; client_order_id = Client_order_id.Generator.next generator
           }
           : Order.Request.t)
      in
      Deferred.unit)
;;

(* The per-connection machinery behind [run], factored out so a test can drive
   it directly. [submit] and [cancel] are the effectful hooks used to talk to
   the exchange; [run] wires them to the RPCs, while tests pass recording
   closures. Returns the outstanding-order table, the inventory table, [post]
   (quote a fresh skewed ladder), and the session-feed event handler. *)
let make (config : Config.t) ~submit ~cancel =
  let client_order_id_table = Client_order_id.Table.create () in
  let inventory_counter = Symbol.Table.create () in
  (* Each market maker owns its own ID space, so [run] and tests don't share a
     counter with [seed_book] (or with each other). *)
  let generator = Client_order_id.Generator.create () in
  let post () =
    let inventory =
      Option.value (Hashtbl.find inventory_counter config.symbol) ~default:0
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
        let%bind () =
          submit
            ({ symbol = config.symbol
             ; participant = config.participant
             ; side = Buy
             ; price = Price.of_int_cents (skewed_fair - offset)
             ; size = Size.of_int config.size_per_level
             ; time_in_force = Day
             ; client_order_id = Client_order_id.Generator.next generator
             }
             : Order.Request.t)
        and () =
          submit
            ({ symbol = config.symbol
             ; participant = config.participant
             ; side = Sell
             ; price = Price.of_int_cents (skewed_fair + offset)
             ; size = Size.of_int config.size_per_level
             ; time_in_force = Day
             ; client_order_id = Client_order_id.Generator.next generator
             }
             : Order.Request.t)
        in
        Deferred.unit)
  in
  let handle_event (event : Exchange_event.t) =
    match event with
    | Fill event ->
      let side, client_order_id =
        if Participant.( = ) config.participant event.aggressor_participant
        then Side.sign event.aggressor_side, event.aggressor_client_order_id
        else
          ( Side.sign (Side.flip event.aggressor_side)
          , event.resting_client_order_id )
      in
      Hashtbl.update inventory_counter event.symbol ~f:(fun count ->
        match count with
        | Some count -> count + (side * Size.to_int event.size)
        | None -> side * Size.to_int event.size);
      let remaining_size =
        Hashtbl.update_and_return
          client_order_id_table
          client_order_id
          ~f:(fun remaining_size ->
            match remaining_size with
            | Some remaining_size -> remaining_size - Size.to_int event.size
            | None -> 0)
      in
      if remaining_size = 0
      then Hashtbl.remove client_order_id_table client_order_id
      else ();
      let keys_to_remove =
        Hashtbl.fold
          client_order_id_table
          ~init:[]
          ~f:(fun ~key:client_order_id ~data:_ acc ->
            client_order_id :: acc)
      in
      List.iter keys_to_remove ~f:(fun client_order_id ->
        don't_wait_for (cancel client_order_id));
      don't_wait_for (post ())
    | Order_cancel request ->
      Hashtbl.remove client_order_id_table request.client_order_id
    | Order_accept accepted ->
      Hashtbl.set
        client_order_id_table
        ~key:accepted.request.client_order_id
        ~data:(Size.to_int accepted.request.size)
    | _ -> ()
  in
  client_order_id_table, inventory_counter, post, handle_event
;;

let run (config : Config.t) conn =
  let submit request =
    let%map result =
      Rpc.Rpc.dispatch_exn Rpc_protocol.submit_order_rpc conn request
    in
    match result with
    | Ok () -> ()
    | Error msg ->
      [%log.error
        "market_maker: submit failed"
          (request : Order.Request.t)
          (msg : Error.t)]
  in
  let cancel client_order_id =
    Deferred.ignore_m
      (Rpc.Rpc.dispatch_exn Rpc_protocol.cancel_order_rpc conn client_order_id)
  in
  let _client_order_id_table, _inventory_counter, post, handle_event =
    make config ~submit ~cancel
  in
  let _ = post () in
  let%bind session_feed, _ =
    Rpc.Pipe_rpc.dispatch_exn Rpc_protocol.session_feed_rpc conn ()
  in
  let _ = Pipe.iter_without_pushback session_feed ~f:handle_event in
  Deferred.return ()
;;
