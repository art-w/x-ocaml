let post r = Js_of_ocaml.Worker.post_message (X_protocol.resp_to_bytes r)
let current = ref (0, 0)
let set_phrase ~cell ~loc = current := (cell, loc)
let cell () = fst !current
let phrase_end () = snd !current

(* Displays and callbacks belong to the cell whose code made them, and go when
   it runs again. *)

let counter = ref 0

let fresh () =
  incr counter;
  !counter

(* display -> its cell, and what to call when the cell runs again *)
let displays : (int, int * (unit -> unit)) Hashtbl.t = Hashtbl.create 8

(* token -> its cell, and the function *)
let callbacks : (int, int * (string -> unit)) Hashtbl.t = Hashtbl.create 8

let add_display on_remove =
  let d = fresh () in
  Hashtbl.replace displays d (cell (), on_remove);
  d

let live d = Hashtbl.mem displays d

let remove d =
  if live d then begin
    Hashtbl.remove displays d;
    post (X_protocol.Remove d)
  end

let add_callback f =
  let k = fresh () in
  Hashtbl.replace callbacks k (cell (), f);
  k

let error what why =
  let open Js_of_ocaml.Js in
  let console = Unsafe.get Unsafe.global "console" in
  ignore
    (Unsafe.meth_call console "error"
       [| Unsafe.inject (string what); Unsafe.inject (string why) |])

(* Code run for a cell other than the one running, a callback or an
   on_remove, runs as part of its own cell: what it displays is that cell's. *)
let as_cell c f =
  let saved = !current in
  current := (c, snd saved);
  Fun.protect ~finally:(fun () -> current := saved) f

(* One that raises is reported, and stops neither the others nor the cell's
   new run. *)
let forget_cell c =
  let gone =
    Hashtbl.fold
      (fun d (c', on_remove) acc ->
        if c' = c then (d, on_remove) :: acc else acc)
      displays []
  in
  Hashtbl.filter_map_inplace
    (fun _ ((c', _) as v) -> if c' = c then None else Some v)
    callbacks;
  List.iter (fun (d, _) -> remove d) gone;
  List.iter
    (fun (_, on_remove) ->
      try as_cell c on_remove
      with e -> error "x-ocaml: an on_remove raised" (Printexc.to_string e))
    gone

let invoke k payload =
  match Hashtbl.find_opt callbacks k with
  | None -> ()
  | Some (c, f) -> as_cell c (fun () -> f payload)
