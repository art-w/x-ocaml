(** Library for putting rich and/or interactive elements on a page *)

val output_html : string -> unit
(** Show HTML under the phrase being run, with its other output, and fixed;
    for HTML that changes, or calls back, see {!html}. *)

(** {1 Displays}

    A display is an element on the page, shown in the display area after the
    cell whose code made it (or whose callback did), until it runs again. Its
    tag names a custom element, which receives [data]
    through its [data] property, now and at each {!update}: data for an
    element not yet defined waits until it is, so a library can load its
    element's script after it first shows one. {{!page-displays}How displays
    work} describes how to write such an element. *)

type display

val display : ?on_remove:(unit -> unit) -> tag:string -> string -> display
(** [display ~tag data] inserts [<tag>] with [data]. [on_remove] is called when
    the display goes because its cell runs again. *)

val update : display -> string -> unit
(** New data for the display, if it is still shown. Data sent while the cell
    is still running is shown as it arrives: a long computation can show
    its progress. *)

val html : ?on_remove:(unit -> unit) -> string -> display
(** A display of HTML, which {!update} replaces. Unlike {!output_html}, it is
    shown after the cell, not under its phrase. Elements in it whose
    [data-callback] attribute is a {!callback} token, as {!string_of_token}
    gives it, call it: an input with its value (["true"] or ["false"] for a
    checkbox) as it changes, anything else when clicked, with its
    [data-payload] attribute.

    Each update replaces the HTML, and with it any input the reader is
    using: therefore keep controls in a display of their own, which is not
    updated. *)

val remove : display -> unit

val live : display -> bool
(** Whether the display is still shown. *)

(** {1 Callbacks} *)

type token

val callback : (string -> unit) -> token
(** [callback f] is a token for [f], which an element on the page calls by
    dispatching an [x-ocaml-callback] event with [detail]
    [{ token; payload }]: [f payload] runs as part of the cell that registered
    it, and so is forgotten when that cell runs again. *)

val string_of_token : token -> string
(** The token as the element gives it back: a decimal integer, which goes in a
    display's data as it is, as a JSON number or an attribute's value. *)

(** {1 Elements} *)

val require : tag:string -> src:string -> unit
(** [require ~tag ~src]: the element [<tag>] is defined by the script at
    [src], relative to the worker's own URL. The page loads it once, unless
    [<tag>] is already defined. *)
