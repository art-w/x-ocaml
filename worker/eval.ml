open Js_of_ocaml_toplevel
open X_protocol

module Value_env : sig
  type t

  val empty : t
  val capture : t -> Ident.t list -> t
  val restore : t -> unit
end = struct
  module String_map = Map.Make (String)

  type t = Obj.t String_map.t

  let empty = String_map.empty

  let capture t idents =
    List.fold_left
      (fun t ident ->
        let name = Translmod.toplevel_name ident in
        let v = Topeval.getvalue name in
        String_map.add name v t)
      t idents

  let restore t = String_map.iter (fun name v -> Topeval.setvalue name v) t
end

module Environment = struct
  let environments = ref []
  let init () = environments := [ (0, !Toploop.toplevel_env, Value_env.empty) ]

  let reset id =
    let rec go id = function
      | [] -> failwith ("no environment " ^ string_of_int id)
      | (id', _, _) :: xs when id' >= id && xs <> [] -> go id xs
      | ((_, typing_env, value_env) as x) :: xs ->
          Toploop.toplevel_env := typing_env;
          Value_env.restore value_env;
          x :: xs
    in
    environments := go id !environments

  let capture id =
    let values =
      match !environments with
      | [] -> invalid_arg "empty environment"
      | (_, previous_env, previous_values) :: _ ->
          let idents = Env.diff previous_env !Toploop.toplevel_env in
          Value_env.capture previous_values idents
    in
    environments := (id, !Toploop.toplevel_env, values) :: !environments
end

let setup_toplevel () =
  let _ = JsooTop.initialize () in
  Sys.interactive := false;
  Environment.init ()

let rec parse_use_file ~caml_ppf lex =
  let _at = lex.Lexing.lex_curr_pos in
  match !Toploop.parse_toplevel_phrase lex with
  | ok -> Ok ok :: parse_use_file ~caml_ppf lex
  | exception End_of_file -> []
  | exception err -> [ Error err ]

let ppx_rewriters = ref []

let preprocess_structure str =
  let open Ast_mapper in
  List.fold_right
    (fun ppx_rewriter str ->
      let mapper = ppx_rewriter [] in
      mapper.structure mapper str)
    !ppx_rewriters str

let preprocess_phrase phrase =
  let open Parsetree in
  match phrase with
  | Ptop_def str -> Ptop_def (preprocess_structure str)
  | Ptop_dir _ as x -> x

let execute ~id ~line_number ~output code_text =
  Environment.reset id;
  let outputs = ref [] in
  let buf = Buffer.create 64 in
  let caml_ppf = Format.formatter_of_buffer buf in
  let content = code_text ^ " ;;" in
  let lexer = Lexing.from_string content in
  Lexing.set_position lexer
    { pos_fname = ""; pos_lnum = line_number; pos_bol = 0; pos_cnum = 0 };
  let phrases = parse_use_file ~caml_ppf lexer in
  Js_of_ocaml.Sys_js.set_channel_flusher stdout (fun str ->
      outputs := Stdout str :: !outputs);
  Js_of_ocaml.Sys_js.set_channel_flusher stderr (fun str ->
      outputs := Stderr str :: !outputs);
  let get_out () =
    Format.pp_print_flush caml_ppf ();
    let meta = Buffer.contents buf in
    Buffer.clear buf;
    let out = if meta = "" then !outputs else Meta meta :: !outputs in
    outputs := [];
    List.rev out
  in
  let respond ~(at_loc : Location.t) =
    let loc = at_loc.loc_end.pos_cnum in
    let out = get_out () in
    output ~loc out
  in
  List.iter
    (function
      | Error err -> Errors.report_error caml_ppf err
      | Ok phrase ->
          let sub_phrases =
            match phrase with
            | Parsetree.Ptop_def s ->
                List.map (fun s -> Parsetree.Ptop_def [ s ]) s
            | Ptop_dir _ -> [ phrase ]
          in
          List.iter
            (fun phrase ->
              let at_loc =
                match phrase with
                | Parsetree.Ptop_def ({ pstr_loc = loc; _ } :: _) -> loc
                | Ptop_dir { pdir_loc = loc; _ } -> loc
                | _ -> assert false
              in
              X_ocaml_lib.id := (id, at_loc.loc_end.pos_cnum);
              try
                Location.reset ();
                let phrase = preprocess_phrase phrase in
                let _r = Toploop.execute_phrase true caml_ppf phrase in
                respond ~at_loc
              with _exn ->
                Errors.report_error caml_ppf _exn;
                respond ~at_loc)
            sub_phrases)
    phrases;
  Environment.capture id;
  get_out ()

let () =
  Ast_mapper.register_function :=
    fun _ f -> ppx_rewriters := f :: !ppx_rewriters
