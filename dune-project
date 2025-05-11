(lang dune 3.10)

(generate_opam_files true)

(package
 (name x-ocaml)
 (depends bos cmdliner ocamlfind js_of_ocaml ppx_blob brr))

(package
 (name ppxlib_register)
 (depends ppxlib))
