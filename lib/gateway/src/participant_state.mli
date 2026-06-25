open! Core
open Jsip_types

type t

val session : t -> Session.t
val client_orders : t -> Client_order_id.Hash_set.t
val create : Session.t -> t
