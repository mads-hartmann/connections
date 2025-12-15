open Lwt.Syntax

let list request =
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page = min 100 (max 1 (Response.parse_query_int "per_page" 10 request)) in
  let* result = Db.Category.list ~page ~per_page () in
  match result with
  | Error msg -> Lwt.return (Response.internal_error msg)
  | Ok response ->
      Lwt.return (Response.json_response (Model.Category.paginated_to_json response))

let get request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* result = Db.Category.get ~id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok None -> Lwt.return (Response.not_found "Category not found")
      | Ok (Some category) ->
          Lwt.return (Response.json_response (Model.Category.to_json category)))

let create request =
  let* parsed = Response.parse_json_body Model.Category.create_request_of_yojson request in
  match parsed with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok { name } ->
      if String.trim name = "" then
        Lwt.return (Response.bad_request "Name cannot be empty")
      else
        let* result = Db.Category.create ~name in
        match result with
        | Error msg -> Lwt.return (Response.internal_error msg)
        | Ok category ->
            Lwt.return
              (Response.json_response ~status:`Created (Model.Category.to_json category))

let delete request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* result = Db.Category.delete ~id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok false -> Lwt.return (Response.not_found "Category not found")
      | Ok true -> Lwt.return (Dream.response ~status:`No_Content ""))

let add_to_person request =
  match
    Response.parse_int_param "person_id" request,
    Response.parse_int_param "category_id" request
  with
  | Error msg, _ | _, Error msg -> Lwt.return (Response.bad_request msg)
  | Ok person_id, Ok category_id -> (
      let* result = Db.Category.add_to_person ~person_id ~category_id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok () -> Lwt.return (Dream.response ~status:`No_Content ""))

let remove_from_person request =
  match
    Response.parse_int_param "person_id" request,
    Response.parse_int_param "category_id" request
  with
  | Error msg, _ | _, Error msg -> Lwt.return (Response.bad_request msg)
  | Ok person_id, Ok category_id -> (
      let* result = Db.Category.remove_from_person ~person_id ~category_id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok () -> Lwt.return (Dream.response ~status:`No_Content ""))

let list_by_person request =
  match Response.parse_int_param "person_id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok person_id -> (
      let* result = Db.Category.get_by_person ~person_id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok categories ->
          Lwt.return (Response.json_response (Model.Category.list_to_json categories)))
