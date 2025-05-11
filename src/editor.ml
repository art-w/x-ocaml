type t = {
  view : Code_mirror.Editor.View.t;
  messages_comp : Code_mirror.Compartment.t;
  lines_comp : Code_mirror.Compartment.t;
  merlin_comp : Code_mirror.Compartment.t;
  changes : Code_mirror.Compartment.t;
  mutable previous_lines : int;
  mutable current_doc : string;
  mutable messages : (int * Brr.El.t list) list;
}

let find_line_ends at doc =
  let rec go i =
    if i >= String.length doc || doc.[i] = '\n' then i else go (i + 1)
  in
  go at

let render_messages cm =
  let open Code_mirror.Editor in
  let open Code_mirror.Decoration in
  let (State.Facet ((module F), it)) = View.decorations () in
  let doc = cm.current_doc in
  let ranges =
    Array.of_list
    @@ List.map (fun (at, msg) ->
           let at = find_line_ends at doc in
           range ~from:at ~to_:at
           @@ widget ~block:true ~side:99
           @@ Widget.make (fun () -> msg))
    @@ List.concat
    @@ List.map (fun (loc, lst) -> List.map (fun m -> (loc, m)) lst)
    @@ List.sort (fun (a, _) (b, _) -> Int.compare a b) cm.messages
  in
  F.of_ it (Range_set.of' ranges)

let refresh_messages ed =
  Code_mirror.Editor.View.dispatch ed.view
    (Code_mirror.Compartment.reconfigure ed.messages_comp
       [ render_messages ed ]);
  Code_mirror.Editor.View.request_measure ed.view

let custom_ln editor =
  Code_mirror.Editor.View.line_numbers (fun x ->
      string_of_int (editor.previous_lines + x))

let refresh_lines ed =
  Code_mirror.Editor.View.dispatch ed.view
  @@ Code_mirror.Compartment.reconfigure ed.lines_comp [ custom_ln ed ]

let configure_merlin ed extensions =
  Code_mirror.Editor.View.dispatch ed.view
  @@ Code_mirror.Compartment.reconfigure ed.merlin_comp extensions

let clear x =
  x.messages <- [];
  refresh_lines x;
  refresh_messages x

let source_of_state s =
  String.concat "\n" @@ Array.to_list @@ Array.map Jstr.to_string
  @@ Code_mirror.Text.to_jstr_array
  @@ Code_mirror.Editor.State.doc s

let source t = source_of_state @@ Code_mirror.Editor.View.state t.view

let prefix_length a b =
  let rec go i =
    if i >= String.length a || i >= String.length b || a.[i] <> b.[i] then i
    else go (i + 1)
  in
  go 0

let basic_setup =
  Jv.get Jv.global "__CM__basic_setup" |> Code_mirror.Extension.of_jv

let make parent =
  let open Code_mirror.Editor in
  let changes = Code_mirror.Compartment.make () in
  let messages = Code_mirror.Compartment.make () in
  let lines = Code_mirror.Compartment.make () in
  let merlin = Code_mirror.Compartment.make () in
  let extensions =
    [|
      basic_setup;
      Code_mirror.Editor.View.line_wrapping ();
      Code_mirror.Compartment.of' lines [];
      Code_mirror.Compartment.of' messages [];
      Code_mirror.Compartment.of' changes [];
      Code_mirror.Compartment.of' merlin [];
    |]
  in
  let config = State.Config.create ~doc:Jstr.empty ~extensions () in
  let state = State.create ~config () in
  let opts = View.opts ~state ~parent () in
  let view = View.create ~opts () in
  {
    previous_lines = 0;
    current_doc = "";
    messages = [];
    view;
    messages_comp = messages;
    lines_comp = lines;
    merlin_comp = merlin;
    changes;
  }

let set_current_doc t new_doc =
  let at = prefix_length t.current_doc new_doc in
  t.current_doc <- new_doc;
  t.messages <- List.filter (fun (loc, _) -> loc < at) t.messages;
  refresh_messages t

let on_change cm fn =
  let has_changed =
    let open Code_mirror.Editor in
    let (State.Facet ((module F), it)) = View.update_listener () in
    F.of_ it (fun ev ->
        if View.Update.doc_changed ev then
          let new_doc = source_of_state (View.Update.state ev) in
          if not (String.equal cm.current_doc new_doc) then (
            set_current_doc cm new_doc;
            fn ()))
  in
  Code_mirror.Editor.View.dispatch cm.view
  @@ Code_mirror.Compartment.reconfigure cm.changes [ has_changed ]

let count_lines str =
  if str = "" then 0
  else
    let nb = ref 1 in
    for i = 0 to String.length str - 1 do
      if str.[i] = '\n' then incr nb
    done;
    !nb

let nb_lines t = t.previous_lines + count_lines t.current_doc

let set_previous_lines t nb =
  t.previous_lines <- nb;
  refresh_lines t

let set_messages t msg =
  t.messages <- msg;
  refresh_messages t

let clear_messages t = set_messages t []
let add_message t loc msg = set_messages t ((loc, msg) :: t.messages)

let set_source t doc =
  set_current_doc t doc;
  Code_mirror.Editor.View.set_doc t.view (Jstr.of_string doc)
