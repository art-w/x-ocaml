(lang dune 3.10)

(generate_opam_files true)

(name x-ocaml)

(source
 (github art-w/x-ocaml))

(authors "Arthur Wendling")

(maintainers "art.wendling@gmail.com")

(license MIT)

(package
 (name x-ocaml)
 (synopsis "OCaml notebooks as a WebComponent")
 (depends
  (bos
   (>= 0.2.1))
  (brr
   (>= 0.0.7))
  (cmdliner
   (>= 1.3.0))
  (js_of_ocaml
   (>= 6.0.1))
  (js_of_ocaml-ppx
   (>= 6.0.1))
  (js_of_ocaml-toplevel
   (>= 6.0.1))
  (merlin-lib
   (>= 5.2.1-502))
  (ocamlformat-lib
   (>= 0.27.0))
  (ocamlfind
   (>= 1.9.8))
  (ppx_blob
   (>= 0.9.0))))

(package
 (name ppxlib_register)
 (synopsis "Register PPX for js_of_ocaml-toplevel")
 (depends
  (ppxlib
   (>= 0.33.0))))
