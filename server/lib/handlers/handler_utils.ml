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
let or_not_found msg = function Some x -> Ok x | None -> Error (not_found msg)

(* Convert Caqti_error.t to response *)
let or_db_error result =
  Result.map_error
    (fun err -> internal_error (Format.asprintf "%a" Caqti_error.pp err))
    result

(* Convert Service.Article.Error.t to response *)
let or_article_error result =
  Result.map_error
    (function
      | Service.Article.Error.Not_found -> not_found "Article not found"
      | Service.Article.Error.Database err ->
          internal_error (Format.asprintf "%a" Caqti_error.pp err))
    result

(* Convert Service.Rss_feed.Error.t to response *)
let or_feed_error result =
  Result.map_error
    (function
      | Service.Rss_feed.Error.Not_found -> not_found "Feed not found"
      | Service.Rss_feed.Error.Database err ->
          internal_error (Format.asprintf "%a" Caqti_error.pp err))
    result

(* Convert Service.Person.Error.t to response *)
let or_person_error result =
  Result.map_error
    (function
      | Service.Person.Error.Not_found -> not_found "Person not found"
      | Service.Person.Error.Database err ->
          internal_error (Format.asprintf "%a" Caqti_error.pp err))
    result

(* Convert Service.Tag.Error.t to response *)
let or_tag_error result =
  Result.map_error
    (function
      | Service.Tag.Error.Not_found -> not_found "Tag not found"
      | Service.Tag.Error.Database err ->
          internal_error (Format.asprintf "%a" Caqti_error.pp err))
    result

(* Convert Service.Person_metadata.Error.t to response *)
let or_person_metadata_error result =
  Result.map_error
    (function
      | Service.Person_metadata.Error.Not_found -> not_found "Metadata not found"
      | Service.Person_metadata.Error.Person_not_found ->
          not_found "Person not found"
      | Service.Person_metadata.Error.Invalid_field_type ->
          bad_request "Invalid field type"
      | Service.Person_metadata.Error.Database err ->
          internal_error (Format.asprintf "%a" Caqti_error.pp err))
    result
