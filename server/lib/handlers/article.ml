open Tapak
open Response.Syntax

let list_by_feed feed_id request =
  let feed_id = Int64.to_int feed_id in
  let* feed_result = Db.Rss_feed.get ~id:feed_id |> Response.or_internal_error in
  let* _ = feed_result |> Response.or_not_found "Feed not found" in
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let* paginated =
    Db.Article.list_by_feed ~feed_id ~page ~per_page
    |> Response.or_internal_error
  in
  Response.json_response (Model.Article.paginated_to_json paginated)

let list_all request =
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let unread_only = Request.query "unread" request = Some "true" in
  let* paginated =
    Db.Article.list_all ~page ~per_page ~unread_only
    |> Response.or_internal_error
  in
  Response.json_response (Model.Article.paginated_to_json paginated)

let get id _request =
  let* result =
    Db.Article.get ~id:(Int64.to_int id) |> Response.or_internal_error
  in
  let* article = result |> Response.or_not_found "Article not found" in
  Response.json_response (Model.Article.to_json article)

let mark_read id request =
  let* { read } =
    Response.parse_json_body Model.Article.mark_read_request_of_yojson request
    |> Response.or_bad_request
  in
  let* result =
    Db.Article.mark_read ~id:(Int64.to_int id) ~read
    |> Response.or_internal_error
  in
  let* article = result |> Response.or_not_found "Article not found" in
  Response.json_response (Model.Article.to_json article)

let mark_all_read feed_id _request =
  let feed_id = Int64.to_int feed_id in
  let* feed_result = Db.Rss_feed.get ~id:feed_id |> Response.or_internal_error in
  let* _ = feed_result |> Response.or_not_found "Feed not found" in
  let* count =
    Db.Article.mark_all_read ~feed_id |> Response.or_internal_error
  in
  Response.json_response (`Assoc [ ("marked_read", `Int count) ])

let delete id _request =
  let* result =
    Db.Article.delete ~id:(Int64.to_int id) |> Response.or_internal_error
  in
  if result then Response.of_string ~body:"" `No_content
  else Response.not_found "Article not found"
