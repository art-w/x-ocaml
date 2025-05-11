val setup_toplevel : unit -> unit

val execute :
  id:int ->
  output:(loc:int -> X_protocol.output list -> unit) ->
  string ->
  X_protocol.output list
