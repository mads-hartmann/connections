open Tapak
open Handler_utils.Syntax

let list (pagination : Pagination.Pagination.t) =
  let* response =
    Db.Category.list ~page:pagination.page
      ~per_page:pagination.per_page ()
    |> Handler_utils.or_internal_error
  in
  Handler_utils.json_response (Model.Category.paginated_to_json response)

let get_category _request id =
  let* result = Db.Category.get ~id |> Handler_utils.or_internal_error in
  let* category = result |> Handler_utils.or_not_found "Category not found" in
  Handler_utils.json_response (Model.Category.to_json category)

let create request =
  let* { name } =
    Handler_utils.parse_json_body Model.Category.create_request_of_yojson
      request
    |> Handler_utils.or_bad_request
  in
  if String.trim name = "" then Handler_utils.bad_request "Name cannot be empty"
  else
    let* category =
      Db.Category.create ~name |> Handler_utils.or_internal_error
    in
    Handler_utils.json_response ~status:`Created
      (Model.Category.to_json category)

let delete_category _request id =
  let* result = Db.Category.delete ~id |> Handler_utils.or_internal_error in
  if result then Response.of_string ~body:"" `No_content
  else Handler_utils.not_found "Category not found"

let add_to_person _request person_id category_id =
  let* () =
    Db.Category.add_to_person ~person_id ~category_id
    |> Handler_utils.or_internal_error
  in
  Response.of_string ~body:"" `No_content

let remove_from_person _request person_id category_id =
  let* () =
    Db.Category.remove_from_person ~person_id ~category_id
    |> Handler_utils.or_internal_error
  in
  Response.of_string ~body:"" `No_content

let list_by_person _request person_id =
  let* categories =
    Db.Category.get_by_person ~person_id |> Handler_utils.or_internal_error
  in
  Handler_utils.json_response (Model.Category.list_to_json categories)

let routes () =
  let open Tapak.Router in
  [
    get (s "categories") |> guard Pagination.Pagination.pagination_guard |> into list;
    get (s "categories" / int) |> request |> into get_category;
    post (s "categories") |> request |> into create;
    delete (s "categories" / int) |> request |> into delete_category;
    get (s "persons" / int / s "categories") |> request |> into list_by_person;
    post (s "persons" / int / s "categories" / int)
    |> request |> into add_to_person;
    delete (s "persons" / int / s "categories" / int)
    |> request |> into remove_from_person;
  ]
