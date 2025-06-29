Embed OCaml notebooks in any web page thanks to WebComponents! Just copy and paste the following script in your html page source to load the integration:

```html
<script async
  src="https://cdn.jsdelivr.net/gh/art-w/x-ocaml.js@2/x-ocaml.js"
  src-worker="https://cdn.jsdelivr.net/gh/art-w/x-ocaml.js@2/x-ocaml.worker+effects.js"
></script>
```

This will introduce a new html tag `<x-ocaml>` to present OCaml code, for example:

```html
<x-ocaml>let x = 42</x-ocaml>
```

The script will initialize a CodeMirror editor integrated with the OCaml interpreter, Merlin and OCamlformat (all running in a web worker). [**Check out the online demo**](https://art-w.github.io/x-ocaml/) for more details, including how to load additional OCaml libraries and ppx in your page.

## Acknowledgments

This project was heavily inspired by the amazing [`sketch.sh`](https://sketch.sh), [@jonludlam's notebooks in Odoc](https://jon.recoil.org/notebooks/foundations/foundations1.html#a-first-session-with-ocaml), [`blogaml` by @panglesd](https://github.com/panglesd/blogaml), and all the wonderful people who made [Try OCaml](https://try.ocamlpro.com/) and other online playgrounds! It was made possible thanks to the invaluable [`js_of_ocaml-toplevel`](https://github.com/ocsigen/js_of_ocaml) library, the magical [`merlin-js` by @voodoos](https://github.com/voodoos/merlin-js), the excellent [CodeMirror bindings by @patricoferris](https://github.com/patricoferris/jsoo-code-mirror/), the guidance of @Julow on `ocamlformat` and the javascript expertise of @xvw.
