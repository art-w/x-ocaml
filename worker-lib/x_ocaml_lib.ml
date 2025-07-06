let id = ref (0, 0)

let output_html m =
  let id, loc = !id in
  Js_of_ocaml.Worker.post_message
    (X_protocol.resp_to_bytes
       (X_protocol.Top_response_at (id, loc, [ Html m ])));
  ()
