open Lwt.Syntax

let json_response ?(status = `OK) json =
  let body = Yojson.Safe.to_string json in
  Dream.response ~status ~headers:[ ("Content-Type", "application/json") ] body

let error_response status message =
  json_response ~status (Person.error_to_json message)

(* URL validation helpers *)
let is_valid_url url =
  try
    let uri = Uri.of_string url in
    match Uri.scheme uri with
    | Some ("http" | "https") -> (
        match Uri.host uri with Some _ -> true | None -> false)
    | _ -> false
  with _ -> false

let validate_url url =
  if String.trim url = "" then Error "URL cannot be empty"
  else if not (is_valid_url url) then
    Error "Invalid URL format: must be http:// or https:// with a valid host"
  else Ok url

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

module RssFeed = struct
  (* POST /persons/:person_id/feeds - Create a new RSS feed *)
  let create request =
    match parse_int_param "person_id" request with
    | Error msg -> Lwt.return (error_response `Bad_Request msg)
    | Ok person_id -> (
        let* body = Dream.body request in
        match Yojson.Safe.from_string body with
        | exception Yojson.Json_error msg ->
            Lwt.return
              (error_response `Bad_Request
                 (Printf.sprintf "Invalid JSON: %s" msg))
        | json -> (
            match Rss_feed.create_request_of_yojson json with
            | exception _ ->
                Lwt.return
                  (error_response `Bad_Request
                     "Invalid request body: expected {\"person_id\": ..., \
                      \"url\": \"...\", \"title\": \"...\"}")
            | { person_id = body_person_id; url; title } -> (
                if body_person_id <> person_id then
                  Lwt.return
                    (error_response `Bad_Request
                       "person_id in URL does not match person_id in body")
                else
                  match validate_url url with
                  | Error msg -> Lwt.return (error_response `Bad_Request msg)
                  | Ok valid_url -> (
                      let* result =
                        Db.Rss_feed.create ~person_id ~url:valid_url ~title
                      in
                      match result with
                      | Error "Person not found" ->
                          Lwt.return
                            (error_response `Not_Found "Person not found")
                      | Error msg ->
                          Lwt.return (error_response `Internal_Server_Error msg)
                      | Ok feed ->
                          Lwt.return
                            (json_response ~status:`Created
                               (Rss_feed.to_json feed))))))

  (* GET /persons/:person_id/feeds - List all feeds for a person *)
  let list_by_person request =
    match parse_int_param "person_id" request with
    | Error msg -> Lwt.return (error_response `Bad_Request msg)
    | Ok person_id -> (
        (* Verify person exists first *)
        let* person_result = Db.Person.get ~id:person_id in
        match person_result with
        | Error msg -> Lwt.return (error_response `Internal_Server_Error msg)
        | Ok None -> Lwt.return (error_response `Not_Found "Person not found")
        | Ok (Some _) -> (
            let page = max 1 (parse_query_int "page" 1 request) in
            let per_page =
              max 1 (min 100 (parse_query_int "per_page" 10 request))
            in
            let* result =
              Db.Rss_feed.list_by_person ~person_id ~page ~per_page
            in
            match result with
            | Error msg ->
                Lwt.return (error_response `Internal_Server_Error msg)
            | Ok paginated ->
                Lwt.return
                  (json_response (Rss_feed.paginated_to_json paginated))))

  (* GET /feeds/:id - Get a single RSS feed *)
  let get request =
    match parse_int_param "id" request with
    | Error msg -> Lwt.return (error_response `Bad_Request msg)
    | Ok id -> (
        let* result = Db.Rss_feed.get ~id in
        match result with
        | Error msg -> Lwt.return (error_response `Internal_Server_Error msg)
        | Ok None -> Lwt.return (error_response `Not_Found "Feed not found")
        | Ok (Some feed) -> Lwt.return (json_response (Rss_feed.to_json feed)))

  (* PUT /feeds/:id - Update an RSS feed *)
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
            match Rss_feed.update_request_of_yojson json with
            | exception _ ->
                Lwt.return
                  (error_response `Bad_Request
                     "Invalid request body: expected {\"url\": \"...\", \
                      \"title\": \"...\"}")
            | { url; title } -> (
                (* Validate URL if provided *)
                let url_result =
                  match url with
                  | None -> Ok None
                  | Some u -> (
                      match validate_url u with
                      | Ok valid -> Ok (Some valid)
                      | Error msg -> Error msg)
                in
                match url_result with
                | Error msg -> Lwt.return (error_response `Bad_Request msg)
                | Ok validated_url -> (
                    let* result =
                      Db.Rss_feed.update ~id ~url:validated_url ~title
                    in
                    match result with
                    | Error msg ->
                        Lwt.return (error_response `Internal_Server_Error msg)
                    | Ok None ->
                        Lwt.return (error_response `Not_Found "Feed not found")
                    | Ok (Some feed) ->
                        Lwt.return (json_response (Rss_feed.to_json feed))))))

  (* DELETE /feeds/:id - Delete an RSS feed *)
  let delete request =
    match parse_int_param "id" request with
    | Error msg -> Lwt.return (error_response `Bad_Request msg)
    | Ok id -> (
        let* result = Db.Rss_feed.delete ~id in
        match result with
        | Error msg -> Lwt.return (error_response `Internal_Server_Error msg)
        | Ok false -> Lwt.return (error_response `Not_Found "Feed not found")
        | Ok true -> Lwt.return (Dream.response ~status:`No_Content ""))
end
