open! Core
open Jsip_types

type t =
  { session : Session.t
  ; client_orders : Order.t Client_order_id.Table.t
  }

let session t = t.session
let client_orders t = t.client_orders

let push_to_client_orders t client_order_id order =
  Hashtbl.add_exn t.client_orders ~key:client_order_id ~data:order
;;

let get_order (t : t) (client_order_id : Client_order_id.t) =
  Hashtbl.find t.client_orders client_order_id
;;

let remove_order t client_order_id = Hashtbl.remove t client_order_id

let create session =
  { session; client_orders = Client_order_id.Table.create () }
;;
