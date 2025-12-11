open Lwt.Syntax

(* GET /feeds/:feed_id/articles - List articles for a feed *)
let list_by_feed request =
  match Utils.parse_int_param "feed_id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok feed_id -> (
      (* Verify feed exists first *)
      let* feed_result = Db.Rss_feed.get ~id:feed_id in
      match feed_result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok None -> Lwt.return (Utils.error_response `Not_Found "Feed not found")
      | Ok (Some _) -> (
          let page = max 1 (Utils.parse_query_int "page" 1 request) in
          let per_page =
            max 1 (min 100 (Utils.parse_query_int "per_page" 10 request))
          in
          let* result = Db.Article.list_by_feed ~feed_id ~page ~per_page in
          match result with
          | Error msg ->
              Lwt.return (Utils.error_response `Internal_Server_Error msg)
          | Ok paginated ->
              Lwt.return
                (Utils.json_response
                   (Model.Article.paginated_to_json paginated))))

(* GET /articles - List all articles with optional unread filter *)
let list_all request =
  let page = max 1 (Utils.parse_query_int "page" 1 request) in
  let per_page =
    max 1 (min 100 (Utils.parse_query_int "per_page" 10 request))
  in
  let unread_only =
    match Dream.query request "unread" with Some "true" -> true | _ -> false
  in
  let* result = Db.Article.list_all ~page ~per_page ~unread_only in
  match result with
  | Error msg -> Lwt.return (Utils.error_response `Internal_Server_Error msg)
  | Ok paginated ->
      Lwt.return
        (Utils.json_response (Model.Article.paginated_to_json paginated))

(* GET /articles/:id - Get a single article *)
let get request =
  match Utils.parse_int_param "id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok id -> (
      let* result = Db.Article.get ~id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok None ->
          Lwt.return (Utils.error_response `Not_Found "Article not found")
      | Ok (Some article) ->
          Lwt.return (Utils.json_response (Model.Article.to_json article)))

(* POST /articles/:id/read - Mark article as read or unread *)
let mark_read request =
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
          match Model.Article.mark_read_request_of_yojson json with
          | exception _ ->
              Lwt.return
                (Utils.error_response `Bad_Request
                   "Invalid request body: expected {\"read\": true|false}")
          | { read } -> (
              let* result = Db.Article.mark_read ~id ~read in
              match result with
              | Error msg ->
                  Lwt.return (Utils.error_response `Internal_Server_Error msg)
              | Ok None ->
                  Lwt.return
                    (Utils.error_response `Not_Found "Article not found")
              | Ok (Some article) ->
                  Lwt.return
                    (Utils.json_response (Model.Article.to_json article)))))

(* POST /feeds/:feed_id/articles/mark-all-read - Mark all articles in a feed as read *)
let mark_all_read request =
  match Utils.parse_int_param "feed_id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok feed_id -> (
      (* Verify feed exists first *)
      let* feed_result = Db.Rss_feed.get ~id:feed_id in
      match feed_result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok None -> Lwt.return (Utils.error_response `Not_Found "Feed not found")
      | Ok (Some _) -> (
          let* result = Db.Article.mark_all_read ~feed_id in
          match result with
          | Error msg ->
              Lwt.return (Utils.error_response `Internal_Server_Error msg)
          | Ok count ->
              Lwt.return
                (Utils.json_response (`Assoc [ ("marked_read", `Int count) ]))))

(* DELETE /articles/:id - Delete an article *)
let delete request =
  match Utils.parse_int_param "id" request with
  | Error msg -> Lwt.return (Utils.error_response `Bad_Request msg)
  | Ok id -> (
      let* result = Db.Article.delete ~id in
      match result with
      | Error msg ->
          Lwt.return (Utils.error_response `Internal_Server_Error msg)
      | Ok false ->
          Lwt.return (Utils.error_response `Not_Found "Article not found")
      | Ok true -> Lwt.return (Dream.response ~status:`No_Content ""))
