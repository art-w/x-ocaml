(** A page's displays: custom elements that code in the worker shows under its
    cells (see X_ocaml_lib), and the callbacks they make. The worker says when
    they go.

    x-ocaml defines one element itself, [<x-ocaml-html>]: its data is HTML, and
    elements in it with a [data-callback] token call back, an input with its
    value (["true"] or ["false"] for a checkbox) when it changes, anything else,
    with its [data-payload], when clicked. *)

type t
(** The displays of a page's cells. There is one for the page, as it assumes one
    worker: display ids are the worker's, and the scripts that {!require} loads
    go into the page itself, where the elements they define are shared by
    everything on it. It knows each cell's element and display area, and each
    display by its id. *)

val create : post:(X_protocol.request -> unit) -> worker_url:string -> unit -> t
(** [post] sends the elements' callbacks to the worker; scripts that define
    elements are relative to [worker_url]. *)

val add_cell : t -> int -> Brr.El.t -> unit
(** The element of cell [id]: its display area goes just after it. *)

val show : t -> cell:int -> display:int -> tag:string -> string -> unit
val update : t -> int -> string -> unit
val remove : t -> int -> unit
val require : t -> tag:string -> src:string -> unit
