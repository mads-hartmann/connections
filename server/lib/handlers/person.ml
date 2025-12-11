open Lwt.Syntax

(* GET /persons - List all persons with pagination and optional search *)
let list request =
  let page = max 1 (Utils.parse_query_int "page" 1 request) in
  let per_page =
    max 1 (min 100 (Utils.parse_query_int "per_page" 10 request))
  in
  let query = Dream.query request "query" in
  let* result = Db.Person.list ~page ~per_page ?query () in
  match result with
  | Error msg -> Lwt.return (Utils.error_response `Internal_Server_Error msg)
  | Ok paginated ->
      Lwt.return
        (Utils.json_response (Model.Person.paginated_to_json paginated))

(* GET /persons/:id - Get a single person *)
let get request =
  match Utils.parse_int_param "id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok id -> (
      let* result = Db.Person.get ~id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok None ->
          Lwt.return (Utils.error_response `Not_Found "Person not found")
      | Ok (Some person) ->
          Lwt.return (Utils.json_response (Model.Person.to_json person)))

(* POST /persons - Create a new person *)
let create request =
  let* body = Dream.body request in
  match Yojson.Safe.from_string body with
  | exception Yojson.Json_error msg ->
      Lwt.return
        (Utils.error_response `Bad_Request
           (Printf.sprintf "Invalid JSON: %s" msg))
  | json -> (
      match Model.Person.create_request_of_yojson json with
      | exception _ ->
          Lwt.return
            (Utils.error_response `Bad_Request
               "Invalid request body: expected {\"name\": \"...\"}")
      | { name } -> (
          if String.trim name = "" then
            Lwt.return
              (Utils.error_response `Bad_Request "Name cannot be empty")
          else
            let* result = Db.Person.create ~name in
            match result with
            | Error msg ->
                Lwt.return (Utils.error_response `Internal_Server_Error msg)
            | Ok person ->
                Lwt.return
                  (Utils.json_response ~status:`Created
                     (Model.Person.to_json person))))

(* PUT /persons/:id - Update an existing person *)
let update request =
  match Utils.parse_int_param "id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok id -> (
      let* body = Dream.body request in
      match Yojson.Safe.from_string body with
      | exception Yojson.Json_error msg ->
          Lwt.return
            (Utils.error_response `Bad_Request
               (Printf.sprintf "Invalid JSON: %s" msg))
      | json -> (
          match Model.Person.update_request_of_yojson json with
          | exception _ ->
              Lwt.return
                (Utils.error_response `Bad_Request
                   "Invalid request body: expected {\"name\": \"...\"}")
          | { name } -> (
              if String.trim name = "" then
                Lwt.return
                  (Utils.error_response `Bad_Request "Name cannot be empty")
              else
                let* result = Db.Person.update ~id ~name in
                match result with
                | Error msg ->
                    Lwt.return (Utils.error_response `Internal_Server_Error msg)
                | Ok None ->
                    Lwt.return
                      (Utils.error_response `Not_Found "Person not found")
                | Ok (Some person) ->
                    Lwt.return
                      (Utils.json_response (Model.Person.to_json person)))))

(* DELETE /persons/:id - Delete a person *)
let delete request =
  match Utils.parse_int_param "id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok id -> (
      let* result = Db.Person.delete ~id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok false ->
          Lwt.return (Utils.error_response `Not_Found "Person not found")
      | Ok true -> Lwt.return (Dream.response ~status:`No_Content ""))
