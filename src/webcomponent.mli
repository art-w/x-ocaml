type t

val define : Jstr.t -> (t -> unit) -> unit
val text_content : t -> string
val get_attribute : t -> string -> Jstr.t option
val as_target : t -> Brr.El.t
val attach_shadow : t -> Brr.El.t
