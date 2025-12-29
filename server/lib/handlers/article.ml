open Tapak
open Handler_utils.Syntax
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

(* Store sw and env for HTTP requests - set by main *)
let sw_ref : Eio.Switch.t option ref = ref None
let env_ref : Eio_unix.Stdenv.base option ref = ref None

let set_context ~sw ~env =
  sw_ref := Some sw;
  env_ref := Some env

let get_context () =
  match (!sw_ref, !env_ref) with
  | Some sw, Some env -> (sw, env)
  | _ -> failwith "Handler context not initialized"

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
  let query = Handler_utils.query "query" request in
  let* paginated =
    Service.Article.list_all ~page:pagination.page ~per_page:pagination.per_page
      ~unread_only ~tag ?query ()
    |> Handler_utils.or_article_error
  in
  Handler_utils.json_response (Model.Article.paginated_to_json paginated)

let get_article _request id =
  let* article = Service.Article.get ~id |> Handler_utils.or_article_error in
  Handler_utils.json_response (Model.Article.to_json article)

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

let refresh_metadata _request id =
  let* article = Service.Article.get ~id |> Handler_utils.or_article_error in
  let sw, env = get_context () in
  let* updated =
    Og_fetcher.fetch_for_article ~sw ~env article
    |> Handler_utils.or_db_error
  in
  let* result =
    updated |> Handler_utils.or_not_found "Article not found after update"
  in
  Handler_utils.json_response (Model.Article.to_json result)

let routes () =
  let open Tapak.Router in
  [
    get (s "feeds" / int / s "articles")
    |> extract Pagination.Pagination.pagination_extractor
    |> into list_by_feed;
    post (s "feeds" / int / s "articles" / s "mark-all-read")
    |> request |> into mark_all_read;
    get (s "articles")
    |> extract Pagination.Pagination.pagination_extractor
    |> request |> into list_all;
    get (s "articles" / int) |> request |> into get_article;
    post (s "articles" / int / s "read") |> request |> into mark_read;
    post (s "articles" / int / s "refresh-metadata")
    |> request |> into refresh_metadata;
    delete (s "articles" / int) |> request |> into delete_article;
  ]
