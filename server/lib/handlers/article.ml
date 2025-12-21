open Response.Syntax

let list_by_feed request =
  let* feed_id =
    Response.parse_int_param "feed_id" request |> Response.or_bad_request
  in
  let* feed_result =
    Db.Rss_feed.get ~id:feed_id |> Response.or_internal_error
  in
  let* _ = feed_result |> Response.or_not_found "Feed not found" in
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let* paginated =
    Db.Article.list_by_feed ~feed_id ~page ~per_page
    |> Response.or_internal_error
  in
  Lwt.return
    (Response.json_response (Model.Article.paginated_to_json paginated))

let list_all request =
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let unread_only = Dream.query request "unread" = Some "true" in
  let* paginated =
    Db.Article.list_all ~page ~per_page ~unread_only
    |> Response.or_internal_error
  in
  Lwt.return
    (Response.json_response (Model.Article.paginated_to_json paginated))

let get request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* result = Db.Article.get ~id |> Response.or_internal_error in
  let* article = result |> Response.or_not_found "Article not found" in
  Lwt.return (Response.json_response (Model.Article.to_json article))

let mark_read request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* { read } =
    Response.parse_json_body Model.Article.mark_read_request_of_yojson request
    |> Response.or_bad_request_lwt
  in
  let* result = Db.Article.mark_read ~id ~read |> Response.or_internal_error in
  let* article = result |> Response.or_not_found "Article not found" in
  Lwt.return (Response.json_response (Model.Article.to_json article))

let mark_all_read request =
  let* feed_id =
    Response.parse_int_param "feed_id" request |> Response.or_bad_request
  in
  let* feed_result =
    Db.Rss_feed.get ~id:feed_id |> Response.or_internal_error
  in
  let* _ = feed_result |> Response.or_not_found "Feed not found" in
  let* count =
    Db.Article.mark_all_read ~feed_id |> Response.or_internal_error
  in
  Lwt.return (Response.json_response (`Assoc [ ("marked_read", `Int count) ]))

let delete request =
  let* id = Response.parse_int_param "id" request |> Response.or_bad_request in
  let* result = Db.Article.delete ~id |> Response.or_internal_error in
  if result then Lwt.return (Dream.response ~status:`No_Content "")
  else Lwt.return (Response.not_found "Article not found")
