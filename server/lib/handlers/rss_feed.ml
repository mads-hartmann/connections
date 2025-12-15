open Lwt.Syntax

let create request =
  match Response.parse_int_param "person_id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok person_id -> (
      let* parsed = Response.parse_json_body Model.Rss_feed.create_request_of_yojson request in
      match parsed with
      | Error msg -> Lwt.return (Response.bad_request msg)
      | Ok { person_id = body_person_id; url; title } ->
          if body_person_id <> person_id then
            Lwt.return (Response.bad_request "person_id in URL does not match person_id in body")
          else
            match Response.validate_url url with
            | Error msg -> Lwt.return (Response.bad_request msg)
            | Ok valid_url -> (
                let* result = Db.Rss_feed.create ~person_id ~url:valid_url ~title in
                match result with
                | Error "Person not found" -> Lwt.return (Response.not_found "Person not found")
                | Error msg -> Lwt.return (Response.internal_error msg)
                | Ok feed ->
                    Lwt.return
                      (Response.json_response ~status:`Created (Model.Rss_feed.to_json feed))))

let list_by_person request =
  match Response.parse_int_param "person_id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok person_id -> (
      let* person_result = Db.Person.get ~id:person_id in
      match person_result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok None -> Lwt.return (Response.not_found "Person not found")
      | Ok (Some _) -> (
          let page = max 1 (Response.parse_query_int "page" 1 request) in
          let per_page = min 100 (max 1 (Response.parse_query_int "per_page" 10 request)) in
          let* result = Db.Rss_feed.list_by_person ~person_id ~page ~per_page in
          match result with
          | Error msg -> Lwt.return (Response.internal_error msg)
          | Ok paginated ->
              Lwt.return (Response.json_response (Model.Rss_feed.paginated_to_json paginated))))

let get request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* result = Db.Rss_feed.get ~id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok None -> Lwt.return (Response.not_found "Feed not found")
      | Ok (Some feed) ->
          Lwt.return (Response.json_response (Model.Rss_feed.to_json feed)))

let update request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* parsed = Response.parse_json_body Model.Rss_feed.update_request_of_yojson request in
      match parsed with
      | Error msg -> Lwt.return (Response.bad_request msg)
      | Ok { url; title } -> (
          let validated_url =
            match url with
            | None -> Ok None
            | Some u -> Result.map Option.some (Response.validate_url u)
          in
          match validated_url with
          | Error msg -> Lwt.return (Response.bad_request msg)
          | Ok url -> (
              let* result = Db.Rss_feed.update ~id ~url ~title in
              match result with
              | Error msg -> Lwt.return (Response.internal_error msg)
              | Ok None -> Lwt.return (Response.not_found "Feed not found")
              | Ok (Some feed) ->
                  Lwt.return (Response.json_response (Model.Rss_feed.to_json feed)))))

let delete request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* result = Db.Rss_feed.delete ~id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok false -> Lwt.return (Response.not_found "Feed not found")
      | Ok true -> Lwt.return (Dream.response ~status:`No_Content ""))

let refresh request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* result = Db.Rss_feed.get ~id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok None -> Lwt.return (Response.not_found "Feed not found")
      | Ok (Some feed) ->
          let* () = Feed_fetcher.process_feed feed in
          Lwt.return (Response.json_response (`Assoc [ ("message", `String "Feed refreshed") ])))
