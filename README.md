Embed OCaml notebooks in any web page thanks to WebComponents! Just copy and paste the following script in your html page source to load the integration:

```html
<script async
  src="https://cdn.jsdelivr.net/gh/art-w/x-ocaml.js@6/x-ocaml.js"
  src-worker="https://cdn.jsdelivr.net/gh/art-w/x-ocaml.js@6/x-ocaml.worker+effects.js"
  integrity="sha256-S7Y6eXDfxMOTn5ms7TJS4a+0k18d0BzF+v2yr7TX8F4="
  crossorigin="anonymous"
></script>
```

This will introduce a new html tag `<x-ocaml>` to present OCaml code, for example:

```html
<x-ocaml>let x = 42</x-ocaml>
```

The script will initialize a CodeMirror editor integrated with the OCaml interpreter, Merlin and OCamlformat (all running in a web worker). [**Check out the online demo**](https://art-w.github.io/x-ocaml/) for more details, including how to load additional OCaml libraries and ppx in your page.

For an even easier integration, @patricoferris made a command-line tool [`xocmd`](https://github.com/patricoferris/xocmd) to convert markdown files to use `<x-ocaml>`!

## Displays

Code in a cell can put live elements on the page with `X_ocaml_lib`: they can
change after the cell has run, and call the cell back when the reader uses
them.

```ocaml
(* A display of HTML, updated as the computation goes. *)
let is_prime n =
  let rec go d = d * d > n || (n mod d <> 0 && go (d + 1)) in
  n > 1 && go 2

let progress = X_ocaml_lib.html "counting primes"
let () =
  let count = ref 0 in
  for tenth = 1 to 10 do
    for n = (tenth - 1) * 100_000 to (tenth * 100_000) - 1 do
      if is_prime n then incr count
    done;
    X_ocaml_lib.update progress
      (Printf.sprintf "<b>%d0%%</b>: %d primes so far" tenth !count)
  done

(* A button that calls OCaml back. *)
let hello =
  X_ocaml_lib.string_of_token
  @@ X_ocaml_lib.callback (fun _ -> X_ocaml_lib.update progress "hello!")
let () =
  ignore
    (X_ocaml_lib.html
       (Printf.sprintf {|<button data-callback="%s">say hello</button>|} hello))
```

Any custom element can be a display: `X_ocaml_lib.display ~tag data` shows a
`<tag>` element under the cell and gives it `data` through its `data` property,
and `X_ocaml_lib.require ~tag ~src` loads the script that defines it, relative
to the worker. An element calls back by dispatching an `x-ocaml-callback` event
with `detail` `{ token, payload }`. Displays and callbacks belong to their cell,
and go when it runs again. [`examples/displays.html`](examples/displays.html)
shows a live estimate, sliders driving a plot, a canvas animated from OCaml,
KaTeX, Mermaid and sound, each with an element of a few dozen lines at most.
[`doc/displays.mld`](doc/displays.mld) (`dune build @doc` renders it) shows
how the page and the worker work together to do it.

## Compilation

To avoid relying on a public CDN and host your own copy of the `x-ocaml` scripts, you can reproduce the javascript files with:

```shell
$ git clone --recursive https://github.com/art-w/x-ocaml
$ cd x-ocaml

# Install the dependencies with either dune:
x-ocaml/ $ dune pkg lock
# Or with opam:
x-ocaml/ $ opam update && opam install . --deps-only

# Make sure to use the release profile to optimize the js file size
x-ocaml/ $ dune build --profile=release

x-ocaml/ $ ls *.js
x-ocaml.js  x-ocaml.worker+effects.js  x-ocaml.worker.js
```

## Acknowledgments

This project was heavily inspired by the amazing [`sketch.sh`](https://sketch.sh), [@jonludlam's notebooks in Odoc](https://jon.recoil.org/notebooks/foundations/foundations1.html#a-first-session-with-ocaml), [`blogaml` by @panglesd](https://github.com/panglesd/blogaml), and all the wonderful people who made [Try OCaml](https://try.ocamlpro.com/) and other online playgrounds! It was made possible thanks to the invaluable [`js_of_ocaml-toplevel`](https://github.com/ocsigen/js_of_ocaml) library, the magical [`merlin-js` by @voodoos](https://github.com/voodoos/merlin-js), the excellent [CodeMirror bindings by @patricoferris](https://github.com/patricoferris/jsoo-code-mirror/), the guidance of @Julow on `ocamlformat` and the javascript expertise of @xvw.
