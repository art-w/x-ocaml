open Brr

type t = {
  post : X_protocol.request -> unit;
  base : string; (* the worker's URL, which scripts are relative to *)
  cells : (int, El.t) Hashtbl.t; (* cell id -> its element *)
  areas : (int, El.t) Hashtbl.t; (* cell id -> its display area *)
  shown : (int, El.t) Hashtbl.t; (* display id -> element *)
  loaded : (string, unit) Hashtbl.t; (* scripts added to the page *)
}

let url ?base u =
  let args =
    match base with
    | Some b -> [| Jv.of_string u; Jv.of_string b |]
    | None -> [| Jv.of_string u |]
  in
  Jv.to_string (Jv.get (Jv.new' (Jv.get Jv.global "URL") args) "href")

let create ~post ~worker_url () =
  let page = Jv.to_string (Jv.get (Document.to_jv G.document) "baseURI") in
  {
    post;
    base = url ~base:page worker_url;
    cells = Hashtbl.create 8;
    areas = Hashtbl.create 8;
    shown = Hashtbl.create 8;
    loaded = Hashtbl.create 4;
  }

let add_cell t id el = Hashtbl.replace t.cells id el
let registry () = Jv.get Jv.global "customElements"

let defined tag =
  not (Jv.is_none (Jv.call (registry ()) "get" [| Jv.of_string tag |]))

(* <x-ocaml-html>, the one element x-ocaml defines itself: its data is HTML,
   shown as it is, and elements in it with a data-callback token call back,
   an input with its value when it changes, anything else when clicked. *)
let html_element =
  {|(function () {
  function input(el) { return el.tagName === 'INPUT' || el.tagName === 'SELECT' || el.tagName === 'TEXTAREA'; }
  function value(el) {
    if (el.type === 'checkbox' || el.type === 'radio') return String(el.checked);
    if (input(el)) return el.value;
    return el.getAttribute('data-payload') || '';
  }
  return class extends HTMLElement {
    constructor() {
      super();
      const call = (ev, inputs) => {
        const el = ev.target.closest && ev.target.closest('[data-callback]');
        if (!el || !this.contains(el) || input(el) !== inputs) return;
        this.dispatchEvent(new CustomEvent('x-ocaml-callback', { bubbles: true,
          detail: { token: Number(el.getAttribute('data-callback')), payload: value(el) } }));
      };
      this.addEventListener('click', (ev) => call(ev, false));
      this.addEventListener('input', (ev) => call(ev, true));
    }
    set data(s) { this._data = s; this.innerHTML = s; }
    get data() { return this._data; }
  };
})()|}

let define_html () =
  if not (defined "x-ocaml-html") then
    ignore
      (Jv.call (registry ()) "define"
         [|
           Jv.of_string "x-ocaml-html";
           Jv.call Jv.global "eval" [| Jv.of_string html_element |];
         |])

(* An element can dispatch anything. Its token must be an int, or there is
   nothing to call; its payload is sent as it is if a string, as nothing if
   missing, and as JSON otherwise. *)
let token v =
  if not (Jstr.equal (Jv.typeof v) (Jstr.v "number")) then None
  else
    let n = Jv.to_float v in
    if Float.is_integer n && Float.abs n <= 1073741823. then
      Some (int_of_float n)
    else None

let payload d =
  match Jv.find d "payload" with
  | None -> ""
  | Some p when Jstr.equal (Jv.typeof p) (Jstr.v "string") -> Jv.to_string p
  | Some p -> (
      let json = Jv.call (Jv.get Jv.global "JSON") "stringify" [| p |] in
      match Jv.to_option Jv.to_string json with Some s -> s | None -> "")

(* A cell's displays go in its display area, just after it, made when the
   first comes; the elements in it call back with x-ocaml-callback events. *)
let area t cell =
  define_html ();
  match Hashtbl.find_opt t.areas cell with
  | Some a -> Some a
  | None ->
      Option.map
        (fun el ->
          let a = El.div ~at:[ At.class' (Jstr.v "x-ocaml-displays") ] [] in
          let on_callback ev =
            let d = Jv.get (Ev.to_jv ev) "detail" in
            if not (Jv.is_none d) then
              match Option.bind (Jv.find d "token") token with
              | Some token -> t.post (Callback (token, payload d))
              | None -> ()
          in
          ignore
            (Ev.listen
               (Ev.Type.create (Jstr.v "x-ocaml-callback"))
               on_callback (El.as_target a));
          ignore (Jv.call (El.to_jv el) "after" [| El.to_jv a |]);
          Hashtbl.replace t.areas cell a;
          a)
        (Hashtbl.find_opt t.cells cell)

(* A property set on an element before its definition arrives would hide the
   definition's setter, so data waits for the element to be defined; if more
   comes meanwhile, only the latest is given. *)
let give el data =
  let jv = El.to_jv el in
  let tag = String.lowercase_ascii (Jstr.to_string (El.tag_name el)) in
  if defined tag then Jv.set jv "data" (Jv.of_string data)
  else begin
    let waiting = not (Jv.is_none (Jv.get jv "xOcamlPending")) in
    Jv.set jv "xOcamlPending" (Jv.of_string data);
    if not waiting then
      let deliver =
        Jv.callback ~arity:1 (fun _ ->
            let d = Jv.get jv "xOcamlPending" in
            Jv.delete jv "xOcamlPending";
            Jv.set jv "data" d)
      in
      ignore
        (Jv.call
           (Jv.call (registry ()) "whenDefined" [| Jv.of_string tag |])
           "then" [| deliver |])
  end

let warn msg = Console.warn [ Jstr.v ("x-ocaml: " ^ msg) ]

(* Only a custom element can be given data, or be waited for: its name
   starts with a lowercase letter and has a hyphen in it. *)
let custom_name tag =
  String.length tag > 0
  && (match tag.[0] with 'a' .. 'z' -> true | _ -> false)
  && String.contains tag '-'

let show t ~cell ~display ~tag data =
  if not (custom_name tag) then
    warn ("cannot display <" ^ tag ^ ">: not a custom element name")
  else
    match area t cell with
    | None -> ()
    | Some a -> (
        match El.v (Jstr.v tag) [] with
        | exception Jv.Error _ ->
            warn ("cannot display <" ^ tag ^ ">: not an element name")
        | el ->
            El.append_children a [ el ];
            Hashtbl.replace t.shown display el;
            give el data)

let update t display data =
  match Hashtbl.find_opt t.shown display with
  | Some el when Jv.to_bool (Jv.get (El.to_jv el) "isConnected") -> give el data
  | _ -> ()

(* A display area left empty goes too. *)
let remove t display =
  match Hashtbl.find_opt t.shown display with
  | None -> ()
  | Some el ->
      let parent = Jv.get (El.to_jv el) "parentNode" in
      El.remove el;
      Hashtbl.remove t.shown display;
      Hashtbl.filter_map_inplace
        (fun _ a ->
          if
            El.to_jv a == parent
            && Jv.to_int (Jv.get (El.to_jv a) "childElementCount") = 0
          then (
            El.remove a;
            None)
          else Some a)
        t.areas

let require t ~tag ~src =
  let url = try url ~base:t.base src with Jv.Error _ -> src in
  if (not (defined tag)) && not (Hashtbl.mem t.loaded url) then begin
    Hashtbl.replace t.loaded url ();
    El.append_children (Document.head G.document)
      [ El.v (Jstr.v "script") ~at:[ At.src (Jstr.v url) ] [] ]
  end
