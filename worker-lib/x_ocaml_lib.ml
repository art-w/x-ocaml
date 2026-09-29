(* What code in a cell calls. What the worker keeps about cells, and calls
   itself, is in X_ocaml_cells, which cells cannot see. *)

let post = X_ocaml_cells.post

let output_html m =
  post
    (X_protocol.Top_response_at
       (X_ocaml_cells.cell (), X_ocaml_cells.phrase_end (), [ Html m ]))

type display = int

let display ?(on_remove = ignore) ~tag data =
  let d = X_ocaml_cells.add_display on_remove in
  post (X_protocol.Display (X_ocaml_cells.cell (), d, tag, data));
  d

let html ?on_remove s = display ?on_remove ~tag:"x-ocaml-html" s
let live = X_ocaml_cells.live
let update d data = if live d then post (X_protocol.Update (d, data))
let remove = X_ocaml_cells.remove

type token = int

let callback = X_ocaml_cells.add_callback
let string_of_token = string_of_int
let required = Hashtbl.create 4

let require ~tag ~src =
  if not (Hashtbl.mem required tag) then begin
    Hashtbl.replace required tag ();
    post (X_protocol.Require (tag, src))
  end
