open Response.Syntax

let preview request =
  let open Lwt.Syntax in
  let* body = Dream.body request in
  if String.trim body = "" then
    Lwt.return (Response.bad_request "Request body cannot be empty")
  else
    let* result = Opml_import.preview body in
    match result with
    | Error msg -> Lwt.return (Response.bad_request msg)
    | Ok response ->
        Lwt.return
          (Response.json_response
             (Opml_import.preview_response_to_json response))

let confirm request =
  let* req =
    Response.parse_json_body Opml_import.confirm_request_of_json request
    |> Response.or_bad_request_lwt
  in
  if List.length req.people = 0 then
    Lwt.return (Response.bad_request "No people selected for import")
  else
    let* response = Opml_import.confirm req |> Response.or_internal_error in
    Lwt.return
      (Response.json_response ~status:`Created
         (Opml_import.confirm_response_to_json response))
