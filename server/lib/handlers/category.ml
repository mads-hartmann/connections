open Lwt.Syntax

let list request =
  let page = max 1 (Utils.parse_query_int "page" 1 request) in
  let per_page = max 1 (min 100 (Utils.parse_query_int "per_page" 10 request)) in
  let* result = Db.Category.list ~page ~per_page () in
  match result with
  | Error msg -> Lwt.return (Utils.error_response `Internal_Server_Error msg)
  | Ok response ->
      Lwt.return
        (Utils.json_response (Model.Category.paginated_to_json response))

let get request =
  match Utils.parse_int_param "id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok id -> (
      let* result = Db.Category.get ~id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok None ->
          Lwt.return (Utils.error_response `Not_Found "Category not found")
      | Ok (Some category) ->
          Lwt.return (Utils.json_response (Model.Category.to_json category)))

let create request =
  let* body = Dream.body request in
  match Yojson.Safe.from_string body with
  | exception Yojson.Json_error msg ->
      Lwt.return
        (Utils.error_response `Bad_Request
           (Printf.sprintf "Invalid JSON: %s" msg))
  | json -> (
      match Model.Category.create_request_of_yojson json with
      | exception _ ->
          Lwt.return
            (Utils.error_response `Bad_Request
               "Invalid request body: expected {\"name\": \"...\"}")
      | { name } -> (
          if String.trim name = "" then
            Lwt.return
              (Utils.error_response `Bad_Request "Name cannot be empty")
          else
            let* result = Db.Category.create ~name in
            match result with
            | Error msg ->
                Lwt.return (Utils.error_response `Internal_Server_Error msg)
            | Ok category ->
                Lwt.return
                  (Utils.json_response ~status:`Created
                     (Model.Category.to_json category))))

let delete request =
  match Utils.parse_int_param "id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok id -> (
      let* result = Db.Category.delete ~id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok false ->
          Lwt.return (Utils.error_response `Not_Found "Category not found")
      | Ok true -> Lwt.return (Dream.response ~status:`No_Content ""))

let add_to_person request =
  match
    ( Utils.parse_int_param "person_id" request,
      Utils.parse_int_param "category_id" request )
  with
  | Error msg, _ | _, Error msg ->
      Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok person_id, Ok category_id -> (
      let* result = Db.Category.add_to_person ~person_id ~category_id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok () -> Lwt.return (Dream.response ~status:`No_Content ""))

let remove_from_person request =
  match
    ( Utils.parse_int_param "person_id" request,
      Utils.parse_int_param "category_id" request )
  with
  | Error msg, _ | _, Error msg ->
      Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok person_id, Ok category_id -> (
      let* result = Db.Category.remove_from_person ~person_id ~category_id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok () -> Lwt.return (Dream.response ~status:`No_Content ""))

let list_by_person request =
  match Utils.parse_int_param "person_id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok person_id -> (
      let* result = Db.Category.get_by_person ~person_id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok categories ->
          Lwt.return
            (Utils.json_response (Model.Category.list_to_json categories)))
