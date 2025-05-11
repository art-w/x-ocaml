open Brr

type t = Jv.t

let mutation_observer = Jv.get Jv.global "MutationObserver"

let create callback =
  let callback = Jv.callback ~arity:2 callback in
  Jv.new' mutation_observer [| callback |]

let disconnect t =
  let _ : Jv.t = Jv.call t "disconnect" [||] in
  ()

let observe t ~target =
  let config =
    Jv.obj
      Jv.[| ("attributes", true'); ("childList", true'); ("subtree", true') |]
  in
  let _ : Jv.t = Jv.call t "observe" [| El.to_jv target; config |] in
  ()
