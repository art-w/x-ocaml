module Merlin_worker = Worker

let respond m = Js_of_ocaml.Worker.post_message (X_protocol.resp_to_bytes m)

let reformat ~id code =
  let code' =
    try Ocamlfmt.fmt code
    with err ->
      Brr.Console.error [ "OCamlformat error:"; Printexc.to_string err ];
      code
  in
  if code <> code' then respond (Formatted_source (id, code'));
  code'

let run () =
  Js_of_ocaml.Worker.set_onmessage @@ fun marshaled_message ->
  match X_protocol.req_of_bytes marshaled_message with
  | Merlin (id, action) ->
      respond (Merlin_response (id, Merlin_worker.on_message action))
  | Format_config conf -> Ocamlfmt.configure conf
  | Format (id, code) -> ignore (reformat ~id code : string)
  | Callback (k, payload) -> (
      try X_ocaml_cells.invoke k payload
      with e ->
        Brr.Console.error [ "x-ocaml: a callback raised"; Printexc.to_string e ]
      )
  | Eval (id, line_number, code) ->
      (* What the cell showed or registered when it last ran goes. *)
      X_ocaml_cells.forget_cell id;
      let code = reformat ~id code in
      let output ~loc out = respond (Top_response_at (id, loc, out)) in
      let result = Eval.execute ~output ~id ~line_number code in
      respond (Top_response (id, result))
  | Setup -> Eval.setup_toplevel ()
