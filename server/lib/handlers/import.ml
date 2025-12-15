open Lwt.Syntax

let preview request =
  let* body = Dream.body request in
  if String.trim body = "" then
    Lwt.return (Response.bad_request "Request body cannot be empty")
  else
    let* result = Opml_import.preview body in
    match result with
    | Error msg -> Lwt.return (Response.bad_request msg)
    | Ok response ->
        Lwt.return (Response.json_response (Opml_import.preview_response_to_json response))

let confirm request =
  let* parsed = Response.parse_json_body Opml_import.confirm_request_of_json request in
  match parsed with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok req ->
      if List.length req.people = 0 then
        Lwt.return (Response.bad_request "No people selected for import")
      else
        let* result = Opml_import.confirm req in
        match result with
        | Error msg -> Lwt.return (Response.internal_error msg)
        | Ok response ->
            Lwt.return
              (Response.json_response ~status:`Created
                 (Opml_import.confirm_response_to_json response))
