let id = ref (0, 0)

(* for Ocaml clients with Marshal*)
let output_html m =
  let id, loc = !id in
  Js_of_ocaml.Worker.post_message
    (X_protocol.resp_to_bytes
       (X_protocol.Top_response_at (id, loc, [ Html m ])));
  ()
(* For Javascript clients with Json  *)
let output_html_str m =
  let id, loc = !id in
  Js_of_ocaml.Worker.post_message
    (Js_of_ocaml.Js.string 
      (X_ocaml_json.json_string_of_response 
        (X_protocol.Top_response_at (id, loc, [ Html m ]))));
  ()
