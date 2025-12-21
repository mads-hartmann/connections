open Response.Syntax

let create request =
  let* person_id =
    Response.parse_int_param "person_id" request |> Response.or_bad_request
  in
  let* { person_id = body_person_id; url; title } =
    Response.parse_json_body Model.Rss_feed.create_request_of_yojson request
    |> Response.or_bad_request_lwt
  in
  if body_person_id <> person_id then
    Lwt.return
      (Response.bad_request "person_id in URL does not match person_id in body")
  else
    let* valid_url = Response.validate_url url |> Response.or_bad_request in
    let* feed =
      Db.Rss_feed.create ~person_id ~url:valid_url ~title
      |> Response.or_internal_error
    in
    Lwt.return
      (Response.json_response ~status:`Created (Model.Rss_feed.to_json feed))

let list_by_person request =
  let* person_id =
    Response.parse_int_param "person_id" request |> Response.or_bad_request
  in
  let* person_result =
    Db.Person.get ~id:person_id |> Response.or_internal_error
  in
  let* _ = person_result |> Response.or_not_found "Person not found" in
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let* paginated =
    Db.Rss_feed.list_by_person ~person_id ~page ~per_page
    |> Response.or_internal_error
  in
  Lwt.return
    (Response.json_response (Model.Rss_feed.paginated_to_json paginated))

let get request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* result = Db.Rss_feed.get ~id |> Response.or_internal_error in
  let* feed = result |> Response.or_not_found "Feed not found" in
  Lwt.return (Response.json_response (Model.Rss_feed.to_json feed))

let update request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* { url; title } =
    Response.parse_json_body Model.Rss_feed.update_request_of_yojson request
    |> Response.or_bad_request_lwt
  in
  let* validated_url =
    (match url with
      | None -> Ok None
      | Some u -> Result.map Option.some (Response.validate_url u))
    |> Response.or_bad_request
  in
  let* result =
    Db.Rss_feed.update ~id ~url:validated_url ~title
    |> Response.or_internal_error
  in
  let* feed = result |> Response.or_not_found "Feed not found" in
  Lwt.return (Response.json_response (Model.Rss_feed.to_json feed))

let delete request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* result = Db.Rss_feed.delete ~id |> Response.or_internal_error in
  if result then Lwt.return (Dream.response ~status:`No_Content "")
  else Lwt.return (Response.not_found "Feed not found")

let refresh request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* result = Db.Rss_feed.get ~id |> Response.or_internal_error in
  let* feed = result |> Response.or_not_found "Feed not found" in
  let open Lwt.Syntax in
  let* () = Feed_fetcher.process_feed feed in
  Lwt.return
    (Response.json_response (`Assoc [ ("message", `String "Feed refreshed") ]))

let list_all request =
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let* paginated =
    Db.Rss_feed.list_all_paginated ~page ~per_page |> Response.or_internal_error
  in
  Lwt.return
    (Response.json_response (Model.Rss_feed.paginated_to_json paginated))
