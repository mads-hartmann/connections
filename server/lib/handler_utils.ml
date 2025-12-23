open Tapak

let json_response ?(status = `OK) json =
  let body = Yojson.Safe.to_string json in
  let headers = Piaf.Headers.of_list [ ("content-type", "application/json") ] in
  Response.of_string ~headers ~body status

let error_response status message =
  json_response ~status (Model.Shared.error_to_json message)

let bad_request msg = error_response `Bad_request msg
let not_found msg = error_response `Not_found msg
let internal_error msg = error_response `Internal_server_error msg

(* URL validation helpers *)
let is_valid_url url =
  try
    let uri = Uri.of_string url in
    match Uri.scheme uri with
    | Some ("http" | "https") -> Option.is_some (Uri.host uri)
    | _ -> false
  with _ -> false

let validate_url url =
  if String.trim url = "" then Error "URL cannot be empty"
  else if not (is_valid_url url) then
    Error "Invalid URL format: must be http:// or https:// with a valid host"
  else Ok url

let parse_query_int name default request =
  let uri = Request.uri request in
  Uri.get_query_param uri name
  |> Option.fold ~none:default ~some:(fun v ->
      int_of_string_opt v |> Option.value ~default)

let query name request =
  let uri = Request.uri request in
  Uri.get_query_param uri name

(* JSON body parsing helper *)
let parse_json_body parser request =
  let body = Request.body request in
  match Body.to_string body with
  | Error _ -> Error "Failed to read request body"
  | Ok body_str -> (
      match Yojson.Safe.from_string body_str with
      | exception Yojson.Json_error msg ->
          Error (Printf.sprintf "Invalid JSON: %s" msg)
      | json -> (
          match parser json with
          | exception _ -> Error "Invalid request body format"
          | result -> Ok result))

(* Monadic syntax for handlers - errors short-circuit as responses *)
module Syntax = struct
  let ( let* ) result f =
    match result with Error response -> response | Ok value -> f value
end

(* Convert string errors to response errors *)
let or_bad_request result = Result.map_error bad_request result

let or_internal_error result = Result.map_error internal_error result

let or_not_found msg = function
  | Some x -> Ok x
  | None -> Error (not_found msg)
