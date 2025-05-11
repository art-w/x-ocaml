type t

val make : Brr.El.t -> t
val source : t -> string
val set_source : t -> string -> unit
val clear : t -> unit
val nb_lines : t -> int
val set_previous_lines : t -> int -> unit
val clear_messages : t -> unit
val add_message : t -> int -> Brr.El.t list -> unit
val on_change : t -> (unit -> unit) -> unit
val configure_merlin : t -> Code_mirror.Extension.t list -> unit
