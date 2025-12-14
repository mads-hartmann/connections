open Lwt.Syntax

(* POST /import/opml/preview - Parse OPML and return preview of people/feeds *)
let preview request =
  let* body = Dream.body request in
  if String.trim body = "" then
    Lwt.return
      (Utils.error_response `Bad_Request "Request body cannot be empty")
  else
    let* result = Opml_import.preview body in
    match result with
    | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
    | Ok response ->
        Lwt.return
          (Utils.json_response (Opml_import.preview_response_to_json response))

(* POST /import/opml/confirm - Create selected people/feeds from import *)
let confirm request =
  let* body = Dream.body request in
  match Yojson.Safe.from_string body with
  | exception Yojson.Json_error msg ->
      Lwt.return
        (Utils.error_response `Bad_Request
           (Printf.sprintf "Invalid JSON: %s" msg))
  | json -> (
      match Opml_import.confirm_request_of_json json with
      | exception _ ->
          Lwt.return
            (Utils.error_response `Bad_Request
               "Invalid request body: expected {\"people\": [...]}")
      | request -> (
          if List.length request.people = 0 then
            Lwt.return
              (Utils.error_response `Bad_Request "No people selected for import")
          else
            let* result = Opml_import.confirm request in
            match result with
            | Error msg ->
                Lwt.return (Utils.error_response `Internal_Server_Error msg)
            | Ok response ->
                Lwt.return
                  (Utils.json_response ~status:`Created
                     (Opml_import.confirm_response_to_json response))))
