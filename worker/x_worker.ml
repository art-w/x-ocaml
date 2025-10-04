module Merlin_worker = Worker
open Js_of_ocaml

type protocol_type = Ocaml_Request | Json_Request

let respond protocol m =
  match protocol with
  | Json_Request ->
      Worker.post_message (Js.string (X_ocaml_json.json_string_of_response m))
  | Ocaml_Request -> Worker.post_message (X_protocol.resp_to_bytes m)

let reformat protocol ~id code =
  let code' = try Ocamlfmt.fmt code with err -> code in
  if code <> code' then respond protocol (Formatted_source (id, code'));
  code'

let run () =
  Js_of_ocaml.Worker.set_onmessage @@ fun (msg : 'a Js.t) ->
  let request : protocol_type * X_protocol.request =
    if Js.typeof msg = Js.string "string" then
      let js_string = Js.Unsafe.coerce msg in
      let ocaml_string = Js.to_string js_string in
      let req = Obj.magic X_ocaml_json.request_of_string ocaml_string in
      (Json_Request, req)
    else
      let uint8_array = Js.Unsafe.get msg "c" in
      let ocaml_bytes = Typed_array.Bytes.of_uint8Array uint8_array in
      let req = Marshal.from_bytes ocaml_bytes 0 in
      (Ocaml_Request, req)
  in
  match request with
  | protocol, message -> (
      match message with
      | Merlin (id, action) ->
          respond protocol
            (Merlin_response (id, Merlin_worker.on_message action))
      | Format_config conf -> Ocamlfmt.configure conf
      | Format (id, code) -> ignore (reformat protocol ~id code : string)
      | Eval (id, line_number, code) ->
          let code = reformat protocol ~id code in
          let output ~loc out =
            respond protocol (Top_response_at (id, loc, out))
          in
          let result = Eval.execute ~output ~id ~line_number code in
          respond protocol (Top_response (id, result))
      | Setup -> Eval.setup_toplevel ())
