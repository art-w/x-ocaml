open Brr

type status = Not_run | Running | Run_ok | Request_run

type t = {
  id : int;
  mutable prev : t option;
  mutable next : t option;
  mutable status : status;
  cm : Editor.t;
  worker : Client.t;
  merlin_worker : Merlin_ext.Client.worker;
  autorun: bool;
}

let id t = t.id

let pre_source t =
  let rec go acc t =
    match t.prev with
    | None -> String.concat "\n" acc
    | Some e -> go (Editor.source e.cm :: acc) e
  in
  let s = go [] t in
  if s = "" then s else s ^ " ;;\n"

let rec invalidate_from ~editor =
  editor.status <- Not_run;
  Editor.clear editor.cm;
  let count = Editor.nb_lines editor.cm in
  match editor.next with
  | None -> ()
  | Some editor ->
      Editor.set_previous_lines editor.cm count;
      invalidate_from ~editor

let invalidate_after ~editor =
  editor.status <- Not_run;
  let count = Editor.nb_lines editor.cm in
  match editor.next with
  | None -> ()
  | Some editor ->
      Editor.set_previous_lines editor.cm count;
      invalidate_from ~editor

let rec refresh_lines_from ~editor =
  let count = Editor.nb_lines editor.cm in
  match editor.next with
  | None -> ()
  | Some editor ->
      Editor.set_previous_lines editor.cm count;
      refresh_lines_from ~editor

let rec run editor =
  if editor.status = Running then ()
  else (
    editor.status <- Request_run;
    Editor.clear_messages editor.cm;
    match editor.prev with
    | Some e when e.status <> Run_ok -> run e
    | _ ->
        editor.status <- Running;
        let code_txt = Editor.source editor.cm in
        let line_number = 1 + Editor.get_previous_lines editor.cm in
        Client.eval ~id:editor.id ~line_number editor.worker code_txt)

let set_prev ~prev t =
  let () = match t.prev with None -> () | Some prev -> prev.next <- None in
  t.prev <- prev;
  match prev with
  | None ->
      Editor.set_previous_lines t.cm 0;
      refresh_lines_from ~editor:t;
      if t.autorun then run t
  | Some p ->
      assert (p.next = None);
      p.next <- Some t;
      refresh_lines_from ~editor:p;
      if t.autorun then run t

let set_source_from_html editor this =
  let doc = Webcomponent.text_content this in
  let doc = String.trim doc in
  Editor.set_source editor.cm doc;
  invalidate_from ~editor;
  Client.fmt ~id:editor.id editor.worker doc

let init_css shadow ~extra_style ~inline_style =
  El.append_children shadow
    [
      El.style
        (El.txt (Jstr.of_string [%blob "style.css"])
        ::
        (match inline_style with
        | None -> []
        | Some inline_style ->
            [
              El.txt
              @@ Jstr.of_string (":host{" ^ Jstr.to_string inline_style ^ "}");
            ]));
    ];
  match extra_style with
  | None -> ()
  | Some src_style ->
      El.append_children shadow
        [
          El.link
            ~at:
              [
                At.href src_style;
                At.rel (Jstr.of_string "stylesheet");
                At.type' (Jstr.of_string "text/css");
              ]
            ();
        ]

let init ~id ~autorun ?extra_style ?inline_style worker this =
  let shadow = Webcomponent.attach_shadow this in
  init_css shadow ~extra_style ~inline_style;

  let run_btn = El.button [ El.txt (Jstr.of_string "Run") ] in
  El.append_children shadow
    [ El.div ~at:[ At.class' (Jstr.of_string "run_btn") ] [ run_btn ] ];

  let cm = Editor.make shadow in

  let merlin = Merlin_ext.make ~id worker in
  let merlin_worker = Merlin_ext.Client.make_worker merlin in
  let editor =
    {
      id;
      status = Not_run;
      cm;
      prev = None;
      next = None;
      worker;
      merlin_worker;
      autorun;
    }
  in
  Editor.on_change cm (fun () -> invalidate_after ~editor);
  set_source_from_html editor this;

  Merlin_ext.set_context merlin (fun () -> pre_source editor);
  Editor.configure_merlin cm (fun () -> Merlin_ext.extensions merlin_worker);

  let () =
    Mutation_observer.observe ~target:(Webcomponent.as_target this)
    @@ Mutation_observer.create (fun _ _ -> set_source_from_html editor this)
  in

  let _ : Ev.listener =
    Ev.listen Ev.click (fun _ev -> run editor) (El.as_target run_btn)
  in

  editor

let set_source editor doc =
  Editor.set_source editor.cm doc;
  refresh_lines_from ~editor

let render_message msg =
  let raw_html s =
    let el = El.div [] in
    let el_t = El.to_jv el in
    Jv.set el_t "innerHTML" (Jv.of_jstr @@ Jstr.of_string s);
    el
  in
  let kind, text =
    match msg with
    | X_protocol.Stdout str -> ("stdout", El.txt' str)
    | Stderr str -> ("stderr", El.txt' str)
    | Meta str -> ("meta", El.txt' str)
    | Html str -> ("html", raw_html str)
  in
  El.pre ~at:[ At.class' (Jstr.of_string ("caml_" ^ kind)) ] [ text ]

let add_message t loc msg =
  Editor.add_message t.cm loc (List.map render_message msg)

let completed_run ed msg =
  (if msg <> [] then
     let loc = String.length (Editor.source ed.cm) in
     add_message ed loc msg);
  ed.status <- Run_ok;
  match ed.next with Some e when e.status = Request_run -> run e | _ -> ()

let receive_merlin t msg =
  Merlin_ext.Client.on_message t.merlin_worker
    (Merlin_ext.fix_answer ~pre:(pre_source t) ~doc:(Editor.source t.cm) msg)
