open Ocamlformat_stdlib
open Ocamlformat_lib

let conf = Ocamlformat_lib.Conf.default

let ast source =
  Ocamlformat_lib.Parse_with_comments.parse
    (Ocamlformat_lib.Parse_with_comments.parse_ast conf)
    Structure conf ~input_name:"source" ~source

let fmt source =
  let ast = ast source in
  let ast =
    let ghostify =
      {
        Parser_extended.Ast_mapper.default_mapper with
        location = (fun _ loc -> { loc with loc_ghost = true });
      }
    in
    { ast with ast = ghostify.structure ghostify ast.ast }
  in
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
