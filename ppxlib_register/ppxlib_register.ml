let mapper _argv =
  let module Current_ast = Ppxlib_ast.Selected_ast in
  let structure s =
    match s with [] -> [] | _ -> Ppxlib.Driver.map_structure s
  in
  let structure _ st =
    Current_ast.of_ocaml Structure st
    |> structure
    |> Current_ast.to_ocaml Structure
  in
  let signature _ si =
    Current_ast.of_ocaml Signature si
    |> Ppxlib.Driver.map_signature
    |> Current_ast.to_ocaml Signature
  in
  { Ast_mapper.default_mapper with structure; signature }

let () = Ast_mapper.register "ppxlib" mapper
