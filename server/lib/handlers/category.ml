open Response.Syntax

let list request =
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let* response =
    Db.Category.list ~page ~per_page () |> Response.or_internal_error
  in
  Lwt.return
    (Response.json_response (Model.Category.paginated_to_json response))

let get request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* result = Db.Category.get ~id |> Response.or_internal_error in
  let* category = result |> Response.or_not_found "Category not found" in
  Lwt.return (Response.json_response (Model.Category.to_json category))

let create request =
  let* { name } =
    Response.parse_json_body Model.Category.create_request_of_yojson request
    |> Response.or_bad_request_lwt
  in
  if String.trim name = "" then
    Lwt.return (Response.bad_request "Name cannot be empty")
  else
    let* category = Db.Category.create ~name |> Response.or_internal_error in
    Lwt.return
      (Response.json_response ~status:`Created
         (Model.Category.to_json category))

let delete request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* result = Db.Category.delete ~id |> Response.or_internal_error in
  if result then Lwt.return (Dream.response ~status:`No_Content "")
  else Lwt.return (Response.not_found "Category not found")

let add_to_person request =
  let* person_id =
    Response.parse_int_param "person_id" request |> Response.or_bad_request
  in
  let* category_id =
    Response.parse_int_param "category_id" request |> Response.or_bad_request
  in
  let* () =
    Db.Category.add_to_person ~person_id ~category_id
    |> Response.or_internal_error
  in
  Lwt.return (Dream.response ~status:`No_Content "")

let remove_from_person request =
  let* person_id =
    Response.parse_int_param "person_id" request |> Response.or_bad_request
  in
  let* category_id =
    Response.parse_int_param "category_id" request |> Response.or_bad_request
  in
  let* () =
    Db.Category.remove_from_person ~person_id ~category_id
    |> Response.or_internal_error
  in
  Lwt.return (Dream.response ~status:`No_Content "")

let list_by_person request =
  let* person_id =
    Response.parse_int_param "person_id" request |> Response.or_bad_request
  in
  let* categories =
    Db.Category.get_by_person ~person_id |> Response.or_internal_error
  in
  Lwt.return (Response.json_response (Model.Category.list_to_json categories))
