open! Core
open Jsip_types

type t

val session : t -> Session.t
val client_orders : t -> Order.t Client_order_id.Table.t
val push_to_client_orders : t -> Client_order_id.t -> Order.t -> unit
val get_order : t -> Client_order_id.t -> Order.t option
val remove_order : t -> Client_order_id.t -> unit
val create : Session.t -> t
