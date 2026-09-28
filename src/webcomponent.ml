let reflect = Jv.get Jv.global "Reflect"
let html_element = Jv.get Jv.global "HTMLElement"

external jv_pure_js_expr : string -> 'a = "caml_pure_js_expr"

let custom_elements = Jv.get Jv.global "customElements"

type t = Jv.t

let define name fn =
  let rec test =
    lazy
      (Jv.callback ~arity:1 (fun () ->
           Jv.call reflect "construct"
             [| html_element; Jv.Jarray.create 0; Lazy.force test |]))
  in
  let test = Lazy.force test in
  (* A prototype of its own: setting connectedCallback on HTMLElement's
     would make every custom element on the page without one of its own
     into a cell. *)
  let proto =
    Jv.call
      (Jv.get Jv.global "Object")
      "create"
      [| Jv.get html_element "prototype" |]
  in
  Jv.set proto "constructor" test;
  Jv.set test "prototype" proto;
  let connected =
    jv_pure_js_expr
      "(function (f) { return function () { var self = this; \
       setTimeout(function () { f(self); }, 0); }; })"
  in
  Jv.set proto "connectedCallback"
    (Jv.apply connected [| Jv.callback ~arity:1 fn |]);
  let _ : Jv.t = Jv.call custom_elements "define" [| Jv.of_jstr name; test |] in
  ()

let text_content t = Jstr.to_string @@ Jv.to_jstr @@ Jv.get t "textContent"
let as_target t = Brr.El.of_jv t

let get_attribute t name =
  let attr = Jv.call t "getAttribute" [| Jv.of_string name |] in
  Jv.to_option Jv.to_string attr

let attach_shadow t =
  Brr.El.of_jv
  @@ Jv.call t "attachShadow"
       [| Jv.obj [| ("mode", Jv.of_jstr @@ Jstr.of_string "open") |] |]
