open Tapak
open Handler_utils.Syntax
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

let list_by_feed (pagination : Pagination.Pagination.t) feed_id =
  let* _ = Service.Rss_feed.get ~id:feed_id |> Handler_utils.or_feed_error in
  let* paginated =
    Service.Article.list_by_feed ~feed_id ~page:pagination.page
      ~per_page:pagination.per_page
    |> Handler_utils.or_article_error
  in
  Handler_utils.json_response (Model.Article.paginated_to_json paginated)

let list_all request (pagination : Pagination.Pagination.t) =
  let unread_only = Handler_utils.query "unread" request = Some "true" in
  let tag = Handler_utils.query "tag" request in
  let* paginated =
    Service.Article.list_all ~page:pagination.page ~per_page:pagination.per_page
      ~unread_only ~tag
    |> Handler_utils.or_article_error
  in
  Handler_utils.json_response (Model.Article.paginated_with_tags_to_json paginated)

let get_article _request id =
  let* article = Service.Article.get ~id |> Handler_utils.or_article_error in
  Handler_utils.json_response (Model.Article.with_tags_to_json article)

type mark_read_request = { read : bool } [@@deriving yojson]

let mark_read request id =
  let* { read } =
    Handler_utils.parse_json_body mark_read_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  let* article =
    Service.Article.mark_read ~id ~read |> Handler_utils.or_article_error
  in
  Handler_utils.json_response (Model.Article.to_json article)

let mark_all_read _request feed_id =
  let* _ = Service.Rss_feed.get ~id:feed_id |> Handler_utils.or_feed_error in
  let* count =
    Service.Article.mark_all_read ~feed_id |> Handler_utils.or_article_error
  in
  Handler_utils.json_response (`Assoc [ ("marked_read", `Int count) ])

let delete_article _request id =
  let* () = Service.Article.delete ~id |> Handler_utils.or_article_error in
  Response.of_string ~body:"" `No_content

let routes () =
  let open Tapak.Router in
  [
    get (s "feeds" / int / s "articles")
    |> guard Pagination.Pagination.pagination_guard
    |> into list_by_feed;
    post (s "feeds" / int / s "articles" / s "mark-all-read")
    |> request |> into mark_all_read;
    get (s "articles")
    |> guard Pagination.Pagination.pagination_guard
    |> request |> into list_all;
    get (s "articles" / int) |> request |> into get_article;
    post (s "articles" / int / s "read") |> request |> into mark_read;
    delete (s "articles" / int) |> request |> into delete_article;
  ]
