module Merlin_protocol = Protocol

type id = int

type request =
  | Merlin of id * Merlin_protocol.action
  | Eval of id * int * string
  | Format of id * string
  | Setup

type output =
  | Stdout of string
  | Stderr of string
  | Meta of string
  | Html of string

type response =
  | Merlin_response of id * Merlin_protocol.answer
  | Top_response of id * output list
  | Top_response_at of id * int * output list
  | Formatted_source of id * string

let req_to_bytes (req : request) = Marshal.to_bytes req []
let resp_to_bytes (req : response) = Marshal.to_bytes req []
let req_of_bytes req : request = Marshal.from_bytes req 0
let resp_of_string resp : response = Marshal.from_string resp 0
