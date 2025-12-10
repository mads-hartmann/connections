open Lwt.Syntax

let json_response ?(status = `OK) json =
  let body = Yojson.Safe.to_string json in
  Dream.response ~status ~headers:[ ("Content-Type", "application/json") ] body

let error_response status message =
  json_response ~status (Person.error_to_json message)

let parse_int_param name request =
  match Dream.param request name with
  | id_str -> (
      match int_of_string_opt id_str with
      | Some id -> Ok id
      | None -> Error (Printf.sprintf "Invalid %s: must be an integer" name))

let parse_query_int name default request =
  match Dream.query request name with
  | None -> default
  | Some value -> (
      match int_of_string_opt value with Some v -> v | None -> default)

module Person = struct
  (* GET /persons - List all persons with pagination and optional search *)
  let list request =
    let page = max 1 (parse_query_int "page" 1 request) in
    let per_page = max 1 (min 100 (parse_query_int "per_page" 10 request)) in
    let query = Dream.query request "query" in
    let* result = Db.Person.list ~page ~per_page ?query () in
    match result with
    | Error msg -> Lwt.return (error_response `Internal_Server_Error msg)
    | Ok paginated ->
        Lwt.return (json_response (Person.paginated_to_json paginated))

  (* GET /persons/:id - Get a single person *)
  let get request =
    match parse_int_param "id" request with
    | Error msg -> Lwt.return (error_response `Bad_Request msg)
    | Ok id -> (
        let* result = Db.Person.get ~id in
        match result with
        | Error msg -> Lwt.return (error_response `Internal_Server_Error msg)
        | Ok None -> Lwt.return (error_response `Not_Found "Person not found")
        | Ok (Some person) -> Lwt.return (json_response (Person.to_json person))
        )

  (* POST /persons - Create a new person *)
  let create request =
    let* body = Dream.body request in
    match Yojson.Safe.from_string body with
    | exception Yojson.Json_error msg ->
        Lwt.return
          (error_response `Bad_Request (Printf.sprintf "Invalid JSON: %s" msg))
    | json -> (
        match Person.create_request_of_yojson json with
        | exception _ ->
            Lwt.return
              (error_response `Bad_Request
                 "Invalid request body: expected {\"name\": \"...\"}")
        | { name } -> (
            if String.trim name = "" then
              Lwt.return (error_response `Bad_Request "Name cannot be empty")
            else
              let* result = Db.Person.create ~name in
              match result with
              | Error msg ->
                  Lwt.return (error_response `Internal_Server_Error msg)
              | Ok person ->
                  Lwt.return
                    (json_response ~status:`Created (Person.to_json person))))

  (* PUT /persons/:id - Update an existing person *)
  let update request =
    match parse_int_param "id" request with
    | Error msg -> Lwt.return (error_response `Bad_Request msg)
    | Ok id -> (
        let* body = Dream.body request in
        match Yojson.Safe.from_string body with
        | exception Yojson.Json_error msg ->
            Lwt.return
              (error_response `Bad_Request
                 (Printf.sprintf "Invalid JSON: %s" msg))
        | json -> (
            match Person.update_request_of_yojson json with
            | exception _ ->
                Lwt.return
                  (error_response `Bad_Request
                     "Invalid request body: expected {\"name\": \"...\"}")
            | { name } -> (
                if String.trim name = "" then
                  Lwt.return
                    (error_response `Bad_Request "Name cannot be empty")
                else
                  let* result = Db.Person.update ~id ~name in
                  match result with
                  | Error msg ->
                      Lwt.return (error_response `Internal_Server_Error msg)
                  | Ok None ->
                      Lwt.return (error_response `Not_Found "Person not found")
                  | Ok (Some person) ->
                      Lwt.return (json_response (Person.to_json person)))))

  (* DELETE /persons/:id - Delete a person *)
  let delete request =
    match parse_int_param "id" request with
    | Error msg -> Lwt.return (error_response `Bad_Request msg)
    | Ok id -> (
        let* result = Db.Person.delete ~id in
        match result with
        | Error msg -> Lwt.return (error_response `Internal_Server_Error msg)
        | Ok false -> Lwt.return (error_response `Not_Found "Person not found")
        | Ok true -> Lwt.return (Dream.response ~status:`No_Content ""))
end
