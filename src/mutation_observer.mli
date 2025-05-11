open Brr

type t

val create : (Jv.t -> Jv.t -> unit) -> t
val observe : t -> target:El.t -> unit
val disconnect : t -> unit
