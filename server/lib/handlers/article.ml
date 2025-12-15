open Lwt.Syntax

let list_by_feed request =
  match Response.parse_int_param "feed_id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok feed_id -> (
      let* feed_result = Db.Rss_feed.get ~id:feed_id in
      match feed_result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok None -> Lwt.return (Response.not_found "Feed not found")
      | Ok (Some _) -> (
          let page = max 1 (Response.parse_query_int "page" 1 request) in
          let per_page =
            min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
          in
          let* result = Db.Article.list_by_feed ~feed_id ~page ~per_page in
          match result with
          | Error msg -> Lwt.return (Response.internal_error msg)
          | Ok paginated ->
              Lwt.return
                (Response.json_response
                   (Model.Article.paginated_to_json paginated))))

let list_all request =
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let unread_only = Dream.query request "unread" = Some "true" in
  let* result = Db.Article.list_all ~page ~per_page ~unread_only in
  match result with
  | Error msg -> Lwt.return (Response.internal_error msg)
  | Ok paginated ->
      Lwt.return
        (Response.json_response (Model.Article.paginated_to_json paginated))

let get request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* result = Db.Article.get ~id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok None -> Lwt.return (Response.not_found "Article not found")
      | Ok (Some article) ->
          Lwt.return (Response.json_response (Model.Article.to_json article)))

let mark_read request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* parsed =
        Response.parse_json_body Model.Article.mark_read_request_of_yojson
          request
      in
      match parsed with
      | Error msg -> Lwt.return (Response.bad_request msg)
      | Ok { read } -> (
          let* result = Db.Article.mark_read ~id ~read in
          match result with
          | Error msg -> Lwt.return (Response.internal_error msg)
          | Ok None -> Lwt.return (Response.not_found "Article not found")
          | Ok (Some article) ->
              Lwt.return
                (Response.json_response (Model.Article.to_json article))))

let mark_all_read request =
  match Response.parse_int_param "feed_id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok feed_id -> (
      let* feed_result = Db.Rss_feed.get ~id:feed_id in
      match feed_result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok None -> Lwt.return (Response.not_found "Feed not found")
      | Ok (Some _) -> (
          let* result = Db.Article.mark_all_read ~feed_id in
          match result with
          | Error msg -> Lwt.return (Response.internal_error msg)
          | Ok count ->
              Lwt.return
                (Response.json_response
                   (`Assoc [ ("marked_read", `Int count) ]))))

let delete request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* result = Db.Article.delete ~id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok false -> Lwt.return (Response.not_found "Article not found")
      | Ok true -> Lwt.return (Dream.response ~status:`No_Content ""))
