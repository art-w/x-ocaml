open Ocamlformat_stdlib
open Ocamlformat_lib
module Format_ = Ocamlformat_format.Format_
module Parser_extended = Ocamlformat_parser_extended

let default_conf = Ocamlformat_lib.Conf.default

let default_conf =
  {
    default_conf with
    opr_opts =
      {
        default_conf.opr_opts with
        ocaml_version = Conf.Elt.make (Ocaml_version.v 5 3) `Default;
      };
  }

let ghost_loc =
  Ocamlformat_ocaml_common.Warnings.ghost_loc_in_file ".ocamlformat"

let parse_conf str =
  List.fold_left
    ~f:(fun conf line ->
      match Conf.parse_line conf ~from:(`File ghost_loc) line with
      | Ok conf -> conf
      | Error err ->
          Brr.Console.error
            [ "OCamlformat config error:"; line; Conf.Error.to_string err ];
          conf)
    ~init:default_conf
    (String.split_on_chars ~on:[ '\n' ] str)

let conf = ref (`Conf default_conf)

let configure = function
  | "disable" -> conf := `Disable
  | str -> conf := `Conf (parse_conf str)

let ast ~conf source =
  Ocamlformat_lib.Parse_with_comments.parse
    (Ocamlformat_lib.Parse_with_comments.parse_ast conf)
    Structure conf ~input_name:"source" ~source

let fmt ~conf source =
  let ast = ast ~conf source in
  let with_buffer_formatter ~buffer_size k =
    let buffer = Buffer.create buffer_size in
    let fs = Format_.formatter_of_buffer buffer in
    Fmt.eval fs k;
    Format_.pp_print_flush fs ();
    if Buffer.length buffer > 0 then Format_.pp_print_newline fs ();
    Buffer.contents buffer
  in
  let print (ast : _ Parse_with_comments.with_comments) =
    let open Fmt in
    let debug = conf.opr_opts.debug.v in
    with_buffer_formatter ~buffer_size:1000
      (set_margin conf.fmt_opts.margin.v
      $ set_max_indent conf.fmt_opts.max_indent.v
      $ Fmt_ast.fmt_ast Structure ~debug ast.source
          (Ocamlformat_lib.Cmts.init Structure ~debug ast.source ast.ast
             ast.comments)
          conf ast.ast)
  in
  String.strip (print ast)

let fmt source =
  match !conf with `Disable -> source | `Conf conf -> fmt ~conf source
