open! Core
open Jsip_types

type t =
  { session : Session.t
  ; client_orders : Order.t Client_order_id.Table.t
  }

let session t = t.session
let client_orders t = t.client_orders

let create session =
  { session; client_orders = Client_order_id.Table.create () }
;;
