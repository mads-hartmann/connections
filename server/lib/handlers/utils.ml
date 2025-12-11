let json_response ?(status = `OK) json =
  let body = Yojson.Safe.to_string json in
  Dream.response ~status ~headers:[ ("Content-Type", "application/json") ] body

let error_response status message =
  json_response ~status (Model.Person.error_to_json message)

(* URL validation helpers *)
let is_valid_url url =
  try
    let uri = Uri.of_string url in
    match Uri.scheme uri with
    | Some ("http" | "https") -> (
        match Uri.host uri with Some _ -> true | None -> false)
    | _ -> false
  with _ -> false

let validate_url url =
  if String.trim url = "" then Error "URL cannot be empty"
  else if not (is_valid_url url) then
    Error "Invalid URL format: must be http:// or https:// with a valid host"
  else Ok url

let parse_int_param name request =
  match Dream.param request name with
  | id_str -> (
      match int_of_string_opt id_str with
      | Some id -> Ok id
      | None -> Error (Printf.sprintf "Invalid %s: must be an integer" name))

let parse_query_int name default request =
  match Dream.query request name with
  | None -> default
  | Some value -> (
      match int_of_string_opt value with Some v -> v | None -> default)
