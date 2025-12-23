open Tapak
open Response.Syntax

let list request =
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let query = Request.query "query" request in
  let* paginated =
    Db.Person.list_with_counts ~page ~per_page ?query ()
    |> Response.or_internal_error
  in
  Response.json_response
    (Model.Person.paginated_with_counts_to_json paginated)

let get id _request =
  let* result = Db.Person.get ~id:(Int64.to_int id) |> Response.or_internal_error in
  let* person = result |> Response.or_not_found "Person not found" in
  Response.json_response (Model.Person.to_json person)

let create request =
  let* { name } =
    Response.parse_json_body Model.Person.create_request_of_yojson request
    |> Response.or_bad_request
  in
  if String.trim name = "" then Response.bad_request "Name cannot be empty"
  else
    let* person = Db.Person.create ~name |> Response.or_internal_error in
    Response.json_response ~status:`Created (Model.Person.to_json person)

let update id request =
  let* { name } =
    Response.parse_json_body Model.Person.update_request_of_yojson request
    |> Response.or_bad_request
  in
  if String.trim name = "" then Response.bad_request "Name cannot be empty"
  else
    let* result =
      Db.Person.update ~id:(Int64.to_int id) ~name |> Response.or_internal_error
    in
    let* person = result |> Response.or_not_found "Person not found" in
    Response.json_response (Model.Person.to_json person)

let delete id _request =
  let* result =
    Db.Person.delete ~id:(Int64.to_int id) |> Response.or_internal_error
  in
  if result then Response.of_string ~body:"" `No_content
  else Response.not_found "Person not found"
