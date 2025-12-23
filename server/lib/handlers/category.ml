open Tapak
open Response.Syntax

let list request =
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let* response =
    Db.Category.list ~page ~per_page () |> Response.or_internal_error
  in
  Response.json_response (Model.Category.paginated_to_json response)

let get id _request =
  let* result =
    Db.Category.get ~id:(Int64.to_int id) |> Response.or_internal_error
  in
  let* category = result |> Response.or_not_found "Category not found" in
  Response.json_response (Model.Category.to_json category)

let create request =
  let* { name } =
    Response.parse_json_body Model.Category.create_request_of_yojson request
    |> Response.or_bad_request
  in
  if String.trim name = "" then Response.bad_request "Name cannot be empty"
  else
    let* category = Db.Category.create ~name |> Response.or_internal_error in
    Response.json_response ~status:`Created (Model.Category.to_json category)

let delete id _request =
  let* result =
    Db.Category.delete ~id:(Int64.to_int id) |> Response.or_internal_error
  in
  if result then Response.of_string ~body:"" `No_content
  else Response.not_found "Category not found"

let add_to_person person_id category_id _request =
  let person_id = Int64.to_int person_id in
  let category_id = Int64.to_int category_id in
  let* () =
    Db.Category.add_to_person ~person_id ~category_id
    |> Response.or_internal_error
  in
  Response.of_string ~body:"" `No_content

let remove_from_person person_id category_id _request =
  let person_id = Int64.to_int person_id in
  let category_id = Int64.to_int category_id in
  let* () =
    Db.Category.remove_from_person ~person_id ~category_id
    |> Response.or_internal_error
  in
  Response.of_string ~body:"" `No_content

let list_by_person person_id _request =
  let person_id = Int64.to_int person_id in
  let* categories =
    Db.Category.get_by_person ~person_id |> Response.or_internal_error
  in
  Response.json_response (Model.Category.list_to_json categories)
