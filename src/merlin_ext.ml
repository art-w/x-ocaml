module Worker = Brr_webworkers.Worker

type t = { id : int; mutable context : unit -> string; client : Client.t }

let set_context t fn = t.context <- fn

let make ~id client =
  { id; context = (fun () -> failwith "Merlin_ext.context"); client }

let fix_position pre_len = function
  | `Offset at -> `Offset (at + pre_len)
  | other -> other

let fix_loc pre_len ({ loc_start; loc_end; _ } as loc : Protocol.Location.t) =
  {
    loc with
    loc_start = { loc_start with pos_cnum = loc_start.pos_cnum - pre_len };
    loc_end = { loc_end with pos_cnum = loc_end.pos_cnum - pre_len };
  }

let fix_request t msg =
  let pre = t.context () in
  let pre_len = String.length pre in
  match msg with
  | Protocol.Complete_prefix (src, position) ->
      let position = fix_position pre_len position in
      Protocol.Complete_prefix (pre ^ src, position)
  | Protocol.Type_enclosing (src, position) ->
      let position = fix_position pre_len position in
      Protocol.Type_enclosing (pre ^ src, position)
  | Protocol.All_errors src -> Protocol.All_errors (pre ^ src)
  | Protocol.Add_cmis _ as other -> other

let fix_answer pre msg =
  let pre_len = String.length pre in
  match (msg : Protocol.answer) with
  | Protocol.Errors errors ->
      Protocol.Errors
        (List.filter_map
           (fun (e : Protocol.error) ->
             let loc = fix_loc pre_len e.loc in
             let from = loc.loc_start.pos_cnum in
             let to_ = loc.loc_end.pos_cnum in
             if from < 0 || to_ < 0 then None else Some { e with loc })
           errors)
  | Protocol.Completions completions ->
      Completions
        {
          completions with
          from = completions.from - pre_len;
          to_ = completions.to_ - pre_len;
        }
  | Protocol.Typed_enclosings typed_enclosings ->
      Typed_enclosings
        (List.map
           (fun (loc, a, b) -> (fix_loc pre_len loc, a, b))
           typed_enclosings)
  | Protocol.Added_cmis -> msg

module Merlin_send = struct
  type nonrec t = t

  let post t msg =
    let msg = fix_request t msg in
    Client.post t.client (Merlin (t.id, msg))
end

module Client = Merlin_client.Make (Merlin_send)
module Ed = Merlin_codemirror.Extensions (Merlin_send)

let extensions t =
  Merlin_codemirror.ocaml :: Array.to_list (Ed.all_extensions t)
