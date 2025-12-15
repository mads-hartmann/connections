let json_response ?(status = `OK) json =
  let body = Yojson.Safe.to_string json in
  Dream.response ~status ~headers:[ ("Content-Type", "application/json") ] body

let error_response status message =
  json_response ~status (Model.Shared.error_to_json message)

let bad_request msg = error_response `Bad_Request msg
let not_found msg = error_response `Not_Found msg
let internal_error msg = error_response `Internal_Server_Error msg

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

let parse_int_param name request =
  match int_of_string_opt (Dream.param request name) with
  | Some id -> Ok id
  | None -> Error (Printf.sprintf "Invalid %s: must be an integer" name)

let parse_query_int name default request =
  Dream.query request name
  |> Option.fold ~none:default ~some:(fun v ->
         int_of_string_opt v |> Option.value ~default)

(* JSON body parsing helper *)
let parse_json_body parser request =
  let open Lwt.Syntax in
  let* body = Dream.body request in
  match Yojson.Safe.from_string body with
  | exception Yojson.Json_error msg ->
      Lwt.return_error (Printf.sprintf "Invalid JSON: %s" msg)
  | json -> (
      match parser json with
      | exception _ -> Lwt.return_error "Invalid request body format"
      | result -> Lwt.return_ok result)
