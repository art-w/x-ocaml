open Bos

let fatal err =
  Format.printf "ERROR: %s@." err;
  exit 1

let or_fail = function Ok x -> x | Error (`Msg m) -> fatal m
let get_result r = fst @@ or_fail @@ OS.Cmd.out_string r
let lines = String.split_on_char '\n'

let jsoo_safe_import =
  {|(function(globalThis){
  "use strict";
   var runtime = globalThis.jsoo_runtime;
   var register_global = runtime.caml_register_global;
   runtime.caml_register_global = function (a,b,c) {
     if (c !== 'Ast_mapper') {
       return register_global(a,b,c);
     }
   };
   var create_file = runtime.jsoo_create_file;
   runtime.jsoo_create_file = function(a,b) {
     try {
       return create_file(a,b);
     } catch(_err) {
      // console.log('jsoo_create_file', a, err);
     }
   };
}
(globalThis));|}

type t = {
  name : string;
  incl : Cmd.t;
  runtime : string option;
  cma : string;
  ppx : bool;
}

let jsoo_compile ~effects t temp_file =
  let toplevel = if t.ppx then Cmd.empty else Cmd.v "--toplevel" in
  let cmd =
    Cmd.(
      v "js_of_ocaml" %% toplevel %% effects %% t.incl % t.cma % "-o"
      % p temp_file)
  in
  let r = get_result @@ OS.Cmd.run_out cmd in
  Format.printf "%s%!" r;
  let temp = Result.get_ok @@ Bos.OS.File.read temp_file in
  let jsoo_runtime =
    match t.runtime with
    | None -> ""
    | Some runtime_file ->
        let build_runtime =
          Cmd.(
            v "js_of_ocaml" % "build-runtime" %% effects % runtime_file % "-o"
            % p temp_file)
          |> OS.Cmd.run_out |> get_result
        in
        Format.printf "build-runtime(%S) = %S@." runtime_file build_runtime;
        let runtime_contents = Result.get_ok @@ Bos.OS.File.read temp_file in
        Printf.sprintf
          {|((function(globalThis) {
                var backup_runtime = globalThis.jsoo_runtime;
                (function(globalThis){%s}(globalThis));
                globalThis.jsoo_runtime = {...globalThis.jsoo_runtime, ...backup_runtime};
            })(globalThis));|}
          runtime_contents
  in
  jsoo_runtime ^ temp

let jsoo_export_cma ~effects t =
  or_fail
  @@ Bos.OS.File.with_tmp_output "x-ocaml.%s.js"
       (fun temp_file _ () -> jsoo_compile ~effects t temp_file)
       ()

let ocamlfind_path lib =
  get_result @@ OS.Cmd.run_out Cmd.(v "ocamlfind" % "query" % lib)

let ocamlfind_includes lib =
  get_result
  @@ OS.Cmd.run_out
       Cmd.(
         v "ocamlfind" % "query" % lib % "-i-format" % "-predicates" % "byte")

let ocamlfind_jsoo_runtime lib =
  get_result
  @@ OS.Cmd.run_out
       Cmd.(
         v "ocamlfind" % "query" % lib % "-format" % "%(jsoo_runtime)"
         % "-predicates" % "byte")

let ocamlfind_cma ~predicate lib =
  get_result
  @@ OS.Cmd.run_out
       Cmd.(
         v "ocamlfind" % "query" % lib % "-a-format" % "-predicates" % predicate)

let ocamlfind_deps ~predicate lib =
  lines @@ get_result
  @@ OS.Cmd.run_out
       Cmd.(
         v "ocamlfind" % "query" % lib % "-r" % "-p-format" % "-predicates"
         % predicate)

module Env = Set.Make (String)

let make ~ppx ~predicate lib =
  let cma = ocamlfind_cma ~predicate lib in
  match lines cma with
  | [] | [ "" ] ->
      Format.printf "skip %s@." lib;
      None
  | [ cma ] ->
      let incl = ocamlfind_includes lib in
      let incl = or_fail @@ Cmd.of_string incl in
      let runtime =
        match ocamlfind_jsoo_runtime lib with
        | "" -> None
        | runtime ->
            let path = ocamlfind_path lib in
            let runtime = path ^ "/" ^ runtime in
            Format.printf "jsoo_runtime(%s) = %S@." lib runtime;
            Some runtime
      in
      Some { incl; runtime; cma; ppx; name = lib }
  | cmas ->
      fatal
        (Format.asprintf "expected one cma for %s, got %i" lib
           (List.length cmas))

let dependencies ~ppx targets env =
  let predicate = if ppx then "ppx_driver,byte" else "byte" in
  let add =
    List.fold_left (fun (env, all) lib ->
        if Env.mem lib env then (env, all)
        else
          let env = Env.add lib env in
          match make ~ppx ~predicate lib with
          | None -> (env, all)
          | Some t -> (env, t :: all))
  in
  let env, selection =
    List.fold_left
      (fun env target ->
        let libs = ocamlfind_deps ~predicate target in
        add env libs)
      (env, []) targets
  in
  (env, List.rev selection)

let output_string output str =
  output (Some (Bytes.of_string str, 0, String.length str))

let main effects targets ppxs output =
  let effects =
    if effects then Cmd.(v "--effects=cps" % "--enable=effect") else Cmd.empty
  in
  let targets =
    match ppxs with
    | [] -> targets
    | _ -> targets @ ppxs @ [ "ppxlib_register" ]
  in
  let env = Env.singleton "x-ocaml.lib" in
  let env, all_ppxs = dependencies ~ppx:true ppxs env in
  let _env, all_libs = dependencies ~ppx:false targets env in
  let all = all_ppxs @ all_libs in
  or_fail @@ or_fail
  @@ (fun f -> f ())
  @@ Bos.OS.File.with_output (Fpath.v output)
  @@ fun output () ->
  let output = output_string output in
  output jsoo_safe_import;
  try
    List.iter
      (fun t ->
        Format.printf "export %s@." t.name;
        let js = jsoo_export_cma ~effects t in
        output js)
      all;
    Ok ()
  with _ -> Error (`Msg "export failed")

open Cmdliner

let arg_output =
  let open Arg in
  required
  & opt (some string) None
  & info [ "o"; "output" ] ~docv:"OUTPUT" ~doc:"Output filename"

let with_effects =
  let open Arg in
  value & flag & info [ "effects" ] ~doc:"Enable effects"

let targets =
  let open Arg in
  non_empty & pos_all string [] & info []

let ppxs =
  let open Arg in
  value & opt_all string [] & info [ "p"; "ppx" ] ~docv:"PPX" ~doc:"PPX"

let main_term = Term.(const main $ with_effects $ targets $ ppxs $ arg_output)
let cmd_main = Cmd.v (Cmd.info "x-ocaml") main_term
let () = exit @@ Cmd.eval cmd_main
