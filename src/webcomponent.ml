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
  Jv.set test "prototype" (Jv.get html_element "prototype");
  Jv.set Jv.global "__xocaml_exported" (Jv.callback ~arity:1 fn);
  Jv.set (Jv.get test "prototype") "connectedCallback"
    (jv_pure_js_expr "(function() { return __xocaml_exported(this) })");
  let _ : Jv.t = Jv.call custom_elements "define" [| Jv.of_jstr name; test |] in
  ()

let text_content t = Jstr.to_string @@ Jv.to_jstr @@ Jv.get t "textContent"
let as_target t = Brr.El.of_jv t

let get_attribute t name =
  let attr = Jv.call t "getAttribute" [| Jv.of_string name |] in
  Jv.to_option (fun s -> s |> Jv.to_string |> Jstr.of_string) attr

let attach_shadow t =
  Brr.El.of_jv
  @@ Jv.call t "attachShadow"
       [| Jv.obj [| ("mode", Jv.of_jstr @@ Jstr.of_string "open") |] |]
