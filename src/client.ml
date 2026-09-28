module Worker = Brr_webworkers.Worker
open Brr

type t = Worker.t

(* The worker is started from a data: URL, where relative URLs mean
   nothing, so resolve them against the page as the browser would. *)
let absolute_url url =
  let base = Jv.get (Document.to_jv G.document) "baseURI" in
  let url = Jv.new' (Jv.get Jv.global "URL") [| Jv.of_string url; base |] in
  Jv.to_string (Jv.get url "href")

let wrap_url ?extra_load url =
  let url = absolute_url url in
  let extra =
    match extra_load with
    | None -> ""
    | Some extra -> "','" ^ absolute_url extra
  in
  let script = "importScripts('" ^ url ^ extra ^ "');" in
  let script = Jstr.of_string script in
  let url =
    match Base64.(encode (data_of_binary_jstr script)) with
    | Ok data -> Jstr.to_string data
    | Error _ -> assert false
  in
  "data:text/javascript;base64," ^ url

let make ?extra_load url =
  Worker.create @@ Jstr.of_string @@ wrap_url ?extra_load url

let on_message t fn =
  let fn m =
    let m = Ev.as_type m in
    let msg = Bytes.to_string @@ Brr_io.Message.Ev.data m in
    fn (X_protocol.resp_of_string msg)
  in
  let _listener =
    Ev.listen Brr_io.Message.Ev.message fn @@ Worker.as_target t
  in
  ()

let post worker msg = Worker.post worker (X_protocol.req_to_bytes msg)

let eval ~id ~line_number worker code =
  post worker (Eval (id, line_number, code))

let fmt ~id worker code = post worker (Format (id, code))
