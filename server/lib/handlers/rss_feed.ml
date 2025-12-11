open Lwt.Syntax

(* POST /persons/:person_id/feeds - Create a new RSS feed *)
let create request =
  match Utils.parse_int_param "person_id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok person_id -> (
      let* body = Dream.body request in
      match Yojson.Safe.from_string body with
      | exception Yojson.Json_error msg ->
          Lwt.return
            (Utils.error_response `Bad_Request
               (Printf.sprintf "Invalid JSON: %s" msg))
      | json -> (
          match Model.Rss_feed.create_request_of_yojson json with
          | exception _ ->
              Lwt.return
                (Utils.error_response `Bad_Request
                   "Invalid request body: expected {\"person_id\": ..., \
                    \"url\": \"...\", \"title\": \"...\"}")
          | { person_id = body_person_id; url; title } -> (
              if body_person_id <> person_id then
                Lwt.return
                  (Utils.error_response `Bad_Request
                     "person_id in URL does not match person_id in body")
              else
                match Utils.validate_url url with
                | Error msg ->
                    Lwt.return (Utils.error_response `Bad_Request msg)
                | Ok valid_url -> (
                    let* result =
                      Db.Rss_feed.create ~person_id ~url:valid_url ~title
                    in
                    match result with
                    | Error "Person not found" ->
                        Lwt.return
                          (Utils.error_response `Not_Found "Person not found")
                    | Error msg ->
                        Lwt.return
                          (Utils.error_response `Internal_Server_Error msg)
                    | Ok feed ->
                        Lwt.return
                          (Utils.json_response ~status:`Created
                             (Model.Rss_feed.to_json feed))))))

(* GET /persons/:person_id/feeds - List all feeds for a person *)
let list_by_person request =
  match Utils.parse_int_param "person_id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok person_id -> (
      (* Verify person exists first *)
      let* person_result = Db.Person.get ~id:person_id in
      match person_result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok None ->
          Lwt.return (Utils.error_response `Not_Found "Person not found")
      | Ok (Some _) -> (
          let page = max 1 (Utils.parse_query_int "page" 1 request) in
          let per_page =
            max 1 (min 100 (Utils.parse_query_int "per_page" 10 request))
          in
          let* result = Db.Rss_feed.list_by_person ~person_id ~page ~per_page in
          match result with
          | Error msg ->
              Lwt.return (Utils.error_response `Internal_Server_Error msg)
          | Ok paginated ->
              Lwt.return
                (Utils.json_response
                   (Model.Rss_feed.paginated_to_json paginated))))

(* GET /feeds/:id - Get a single RSS feed *)
let get request =
  match Utils.parse_int_param "id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok id -> (
      let* result = Db.Rss_feed.get ~id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok None -> Lwt.return (Utils.error_response `Not_Found "Feed not found")
      | Ok (Some feed) ->
          Lwt.return (Utils.json_response (Model.Rss_feed.to_json feed)))

(* PUT /feeds/:id - Update an RSS feed *)
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
          match Model.Rss_feed.update_request_of_yojson json with
          | exception _ ->
              Lwt.return
                (Utils.error_response `Bad_Request
                   "Invalid request body: expected {\"url\": \"...\", \
                    \"title\": \"...\"}")
          | { url; title } -> (
              (* Validate URL if provided *)
              let url_result =
                match url with
                | None -> Ok None
                | Some u -> (
                    match Utils.validate_url u with
                    | Ok valid -> Ok (Some valid)
                    | Error msg -> Error msg)
              in
              match url_result with
              | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
              | Ok validated_url -> (
                  let* result =
                    Db.Rss_feed.update ~id ~url:validated_url ~title
                  in
                  match result with
                  | Error msg ->
                      Lwt.return
                        (Utils.error_response `Internal_Server_Error msg)
                  | Ok None ->
                      Lwt.return
                        (Utils.error_response `Not_Found "Feed not found")
                  | Ok (Some feed) ->
                      Lwt.return
                        (Utils.json_response (Model.Rss_feed.to_json feed))))))

(* DELETE /feeds/:id - Delete an RSS feed *)
let delete request =
  match Utils.parse_int_param "id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok id -> (
      let* result = Db.Rss_feed.delete ~id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok false ->
          Lwt.return (Utils.error_response `Not_Found "Feed not found")
      | Ok true -> Lwt.return (Dream.response ~status:`No_Content ""))

(* POST /feeds/:id/refresh - Manually trigger a feed refresh *)
let refresh request =
  match Utils.parse_int_param "id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok id -> (
      let* result = Db.Rss_feed.get ~id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok None -> Lwt.return (Utils.error_response `Not_Found "Feed not found")
      | Ok (Some feed) ->
          let* () = Feed_fetcher.process_feed feed in
          Lwt.return
            (Utils.json_response
               (`Assoc [ ("message", `String "Feed refreshed") ])))
