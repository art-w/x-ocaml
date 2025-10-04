(****************************************************************************)
(*                             Part 1: READ Path                            *)
(****************************************************************************)
(* These are the local types for safely parsing an incoming JSON request. *)
type id = int

and json_position_rd = {
  pos_fname : string;
  pos_lnum : int;
  pos_bol : int;
  pos_cnum : int;
}

and json_location_rd = {
  loc_start : json_position_rd;
  loc_end : json_position_rd;
  loc_ghost : bool;
}

and json_msource_position_rd = [ `Offset of int ]
and json_static_cmi_rd = { sc_name : string; sc_content : string }

and json_dynamic_cmis_rd = {
  dcs_url : string;
  dcs_toplevel_modules : string list;
  dcs_file_prefixes : string list;
}

and json_cmis_rd = {
  static_cmis : json_static_cmi_rd list;
  dynamic_cmis : json_dynamic_cmis_rd option;
}

and json_merlin_action_rd =
  | Complete_prefix of string * json_msource_position_rd
  | Type_enclosing of string * json_msource_position_rd
  | All_errors of string
  | Add_cmis of json_cmis_rd

and request =
  | Merlin of id * json_merlin_action_rd
  | Eval of id * int * string
  | Format of id * string
  | Format_config of string
  | Setup
[@@deriving of_yojson]

(* This is the public function for parsing a request*)
let request_of_string json_str =
  let json = Yojson.Safe.from_string json_str in
  match request_of_yojson json with Ok msg -> msg | Error _ -> Setup

(****************************************************************************)
(*                             Part 2: WRITE Path                           *)
(****************************************************************************)

(* These are the local "shadow" types for safely creating a JSON response. *)
type json_position_wr = {
  pos_fname : string;
  pos_lnum : int;
  pos_bol : int;
  pos_cnum : int;
}

and json_location_wr = {
  loc_start : json_position_wr;
  loc_end : json_position_wr;
  loc_ghost : bool;
}

and json_location_report_kind_wr =
  [ `Report_error | `Report_warning | `Report_warning_as_error ]

and json_location_error_source_wr =
  [ `Lexer | `Parser | `Typer | `Warning | `Unknown | `Env | `Config ]

and json_error_wr = {
  kind : json_location_report_kind_wr;
  loc : json_location_wr;
  main : string;
  sub : string list;
  source : json_location_error_source_wr;
}

and json_is_tail_position_wr = [ `No | `Tail_position | `Tail_call ]
[@@deriving to_yojson]

type json_compl_kind_wr =
  [ `Value
  | `Variant
  | `Constructor
  | `Label of string
  | `Module
  | `Modtype
  | `Type
  | `Method
  | `Methodcall
  | `Typevar
  | `Exn
  | `Class ]

and json_compl_entry_wr = {
  name : string;
  kind : json_compl_kind_wr;
  desc : string;
  info : string;
}

and json_completions_wr = {
  from : int;
  to_ : int;
  entries : json_compl_entry_wr list;
}
[@@deriving to_yojson]

type json_merlin_answer_wr =
  | Errors of json_error_wr list
  | Completions of json_completions_wr
  | Typed_enclosings of
      (json_location_wr
      * [ `Index of int | `String of string ]
      * json_is_tail_position_wr)
      list
  | Added_cmis
[@@deriving to_yojson]

let yojson_of_response (resp : X_protocol.response) : Yojson.Safe.t =
  let open X_protocol in
  let json_output_to_yojson (o : output) =
    match o with
    | Stdout s -> `List [ `String "Stdout"; `String s ]
    | Stderr s -> `List [ `String "Stderr"; `String s ]
    | Meta s -> `List [ `String "Meta"; `String s ]
    | Html s -> `List [ `String "Html"; `String s ]
  in
  match resp with
  | Top_response (id, outputs) ->
      `List
        [
          `String "Top_response";
          `Int id;
          `List (List.map json_output_to_yojson outputs);
        ]
  | Top_response_at (id, loc, outputs) ->
      `List
        [
          `String "Top_response_at";
          `Int id;
          `Int loc;
          `List (List.map json_output_to_yojson outputs);
        ]
  | Formatted_source (id, src) ->
      `List [ `String "Formatted_source"; `Int id; `String src ]
  | Merlin_response (id, merlin_answer) ->
      let json_answer : json_merlin_answer_wr = Obj.magic merlin_answer in
      `List
        [
          `String "Merlin_response";
          `Int id;
          json_merlin_answer_wr_to_yojson json_answer;
        ]

(* This is the public function for formating a response *)
let json_string_of_response resp =
  let json_ast = yojson_of_response resp in
  Yojson.Safe.to_string json_ast
