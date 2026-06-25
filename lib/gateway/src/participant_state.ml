open! Core
open Jsip_types

type t =
  { session : Session.t
  ; client_orders : Client_order_id.Hash_set.t
  }

let session t = t.session
let client_orders t = t.client_orders

let create session =
  { session; client_orders = Hash_set.create (module Client_order_id) }
;;
