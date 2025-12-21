open Response.Syntax

let list request =
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let query = Dream.query request "query" in
  let* paginated =
    Db.Person.list_with_counts ~page ~per_page ?query ()
    |> Response.or_internal_error
  in
  Lwt.return
    (Response.json_response
       (Model.Person.paginated_with_counts_to_json paginated))

let get request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* result = Db.Person.get ~id |> Response.or_internal_error in
  let* person = result |> Response.or_not_found "Person not found" in
  Lwt.return (Response.json_response (Model.Person.to_json person))

let create request =
  let* { name } =
    Response.parse_json_body Model.Person.create_request_of_yojson request
    |> Response.or_bad_request_lwt
  in
  if String.trim name = "" then
    Lwt.return (Response.bad_request "Name cannot be empty")
  else
    let* person = Db.Person.create ~name |> Response.or_internal_error in
    Lwt.return
      (Response.json_response ~status:`Created (Model.Person.to_json person))

let update request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* { name } =
    Response.parse_json_body Model.Person.update_request_of_yojson request
    |> Response.or_bad_request_lwt
  in
  if String.trim name = "" then
    Lwt.return (Response.bad_request "Name cannot be empty")
  else
    let* result = Db.Person.update ~id ~name |> Response.or_internal_error in
    let* person = result |> Response.or_not_found "Person not found" in
    Lwt.return (Response.json_response (Model.Person.to_json person))

let delete request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* result = Db.Person.delete ~id |> Response.or_internal_error in
  if result then Lwt.return (Dream.response ~status:`No_Content "")
  else Lwt.return (Response.not_found "Person not found")
