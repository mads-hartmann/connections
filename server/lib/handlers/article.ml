open Tapak
open Handler_utils.Syntax

let list_by_feed (pagination : Pagination.pagination) feed_id =
  let* feed_result =
    Db.Rss_feed.get ~id:feed_id |> Handler_utils.or_internal_error
  in
  let* _ = feed_result |> Handler_utils.or_not_found "Feed not found" in
  let* paginated =
    Db.Article.list_by_feed ~feed_id ~page:pagination.page
      ~per_page:pagination.per_page
    |> Handler_utils.or_internal_error
  in
  Handler_utils.json_response (Model.Article.paginated_to_json paginated)

let list_all request (pagination : Pagination.pagination) =
  let unread_only = Handler_utils.query "unread" request = Some "true" in
  let* paginated =
    Db.Article.list_all ~page:pagination.Pagination.page
      ~per_page:pagination.Pagination.per_page ~unread_only
    |> Handler_utils.or_internal_error
  in
  Handler_utils.json_response (Model.Article.paginated_to_json paginated)

let get_article _request id =
  let* result = Db.Article.get ~id |> Handler_utils.or_internal_error in
  let* article = result |> Handler_utils.or_not_found "Article not found" in
  Handler_utils.json_response (Model.Article.to_json article)

let mark_read request id =
  let* { read } =
    Handler_utils.parse_json_body Model.Article.mark_read_request_of_yojson
      request
    |> Handler_utils.or_bad_request
  in
  let* result =
    Db.Article.mark_read ~id ~read |> Handler_utils.or_internal_error
  in
  let* article = result |> Handler_utils.or_not_found "Article not found" in
  Handler_utils.json_response (Model.Article.to_json article)

let mark_all_read _request feed_id =
  let* feed_result =
    Db.Rss_feed.get ~id:feed_id |> Handler_utils.or_internal_error
  in
  let* _ = feed_result |> Handler_utils.or_not_found "Feed not found" in
  let* count =
    Db.Article.mark_all_read ~feed_id |> Handler_utils.or_internal_error
  in
  Handler_utils.json_response (`Assoc [ ("marked_read", `Int count) ])

let delete_article _request id =
  let* result = Db.Article.delete ~id |> Handler_utils.or_internal_error in
  if result then Response.of_string ~body:"" `No_content
  else Handler_utils.not_found "Article not found"

let routes () =
  let open Tapak.Router in
  [
    get (s "feeds" / int / s "articles")
    |> guard Pagination.pagination_guard
    |> into list_by_feed;
    post (s "feeds" / int / s "articles" / s "mark-all-read")
    |> request |> into mark_all_read;
    get (s "articles")
    |> guard Pagination.pagination_guard
    |> request |> into list_all;
    get (s "articles" / int) |> request |> into get_article;
    post (s "articles" / int / s "read") |> request |> into mark_read;
    delete (s "articles" / int) |> request |> into delete_article;
  ]
