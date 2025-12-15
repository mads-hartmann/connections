(* Tests for Article model, DB, and handlers *)

open Lwt.Syntax
open Connections_server
open Test_helpers

(* ============================================
   JSON Serialization Tests
   ============================================ *)

let test_article_to_json () =
  let article =
    {
      Model.Article.id = 1;
      feed_id = 2;
      title = Some "Test Article";
      url = "https://example.com/article";
      published_at = Some "2024-01-01 12:00:00";
      content = Some "Article content";
      author = Some "John Doe";
      image_url = None;
      created_at = "2024-01-01 12:00:00";
      read_at = None;
    }
  in
  let json = Model.Article.to_json article in
  match json with
  | `Assoc fields ->
      Alcotest.(check bool) "has id field" true (List.mem_assoc "id" fields);
      Alcotest.(check bool) "has url field" true (List.mem_assoc "url" fields);
      Alcotest.(check bool)
        "has feed_id field" true
        (List.mem_assoc "feed_id" fields)
  | _ -> Alcotest.fail "expected JSON object"

let test_article_paginated_to_json () =
  let response = Model.Shared.Paginated.make ~data:[] ~page:1 ~per_page:10 ~total:0 in
  let json = Model.Article.paginated_to_json response in
  match json with
  | `Assoc fields ->
      Alcotest.(check bool) "has data field" true (List.mem_assoc "data" fields);
      Alcotest.(check bool)
        "has total field" true
        (List.mem_assoc "total" fields)
  | _ -> Alcotest.fail "expected JSON object"

let json_suite =
  [
    sync_test "Article.to_json" test_article_to_json;
    sync_test "Article.paginated_to_json" test_article_paginated_to_json;
  ]

(* ============================================
   Database Tests
   ============================================ *)

let test_db_article_upsert () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let input =
    {
      Model.Article.feed_id = feed.id;
      title = Some "Test Article";
      url = "https://example.com/article1";
      published_at = Some "2024-01-01 12:00:00";
      content = Some "Article content";
      author = Some "John Doe";
      image_url = None;
    }
  in
  let* result = Db.Article.upsert input in
  match result with
  | Error msg -> Alcotest.fail ("upsert failed: " ^ msg)
  | Ok () -> Lwt.return_unit

let test_db_article_upsert_many () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let inputs =
    [
      {
        Model.Article.feed_id = feed.id;
        title = Some "Article 1";
        url = "https://example.com/article1";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      };
      {
        Model.Article.feed_id = feed.id;
        title = Some "Article 2";
        url = "https://example.com/article2";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      };
    ]
  in
  let* result = Db.Article.upsert_many inputs in
  match result with
  | Error msg -> Alcotest.fail ("upsert_many failed: " ^ msg)
  | Ok count ->
      Alcotest.(check int) "inserted 2 articles" 2 count;
      Lwt.return_unit

let test_db_article_upsert_duplicate () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let input =
    {
      Model.Article.feed_id = feed.id;
      title = Some "Test Article";
      url = "https://example.com/article1";
      published_at = None;
      content = None;
      author = None;
      image_url = None;
    }
  in
  let* _ = Db.Article.upsert input in
  (* Insert same URL again - should be ignored *)
  let* result = Db.Article.upsert input in
  match result with
  | Error msg -> Alcotest.fail ("upsert duplicate failed: " ^ msg)
  | Ok () -> Lwt.return_unit

let test_db_article_get () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let input =
    {
      Model.Article.feed_id = feed.id;
      title = Some "Get Test Article";
      url = "https://example.com/get-test";
      published_at = None;
      content = None;
      author = None;
      image_url = None;
    }
  in
  let* _ = Db.Article.upsert input in
  (* List to get the ID *)
  let* list_result =
    Db.Article.list_by_feed ~feed_id:feed.id ~page:1 ~per_page:10
  in
  match list_result with
  | Error msg -> Alcotest.fail ("list failed: " ^ msg)
  | Ok paginated -> (
      match paginated.data with
      | [] -> Alcotest.fail "no articles found"
      | article :: _ -> (
          let* get_result = Db.Article.get ~id:article.id in
          match get_result with
          | Error msg -> Alcotest.fail ("get failed: " ^ msg)
          | Ok None -> Alcotest.fail "article not found"
          | Ok (Some fetched) ->
              Alcotest.(check string)
                "url matches" "https://example.com/get-test" fetched.url;
              Alcotest.(check (option string))
                "title matches" (Some "Get Test Article") fetched.title;
              Lwt.return_unit))

let test_db_article_list_by_feed () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let inputs =
    [
      {
        Model.Article.feed_id = feed.id;
        title = Some "Article 1";
        url = "https://example.com/a1";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      };
      {
        Model.Article.feed_id = feed.id;
        title = Some "Article 2";
        url = "https://example.com/a2";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      };
      {
        Model.Article.feed_id = feed.id;
        title = Some "Article 3";
        url = "https://example.com/a3";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      };
    ]
  in
  let* _ = Db.Article.upsert_many inputs in
  let* result = Db.Article.list_by_feed ~feed_id:feed.id ~page:1 ~per_page:10 in
  match result with
  | Error msg -> Alcotest.fail ("list_by_feed failed: " ^ msg)
  | Ok paginated ->
      Alcotest.(check int) "total is 3" 3 paginated.total;
      Alcotest.(check int) "data length is 3" 3 (List.length paginated.data);
      Lwt.return_unit

let test_db_article_list_all () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let inputs =
    [
      {
        Model.Article.feed_id = feed.id;
        title = Some "Article 1";
        url = "https://example.com/a1";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      };
      {
        Model.Article.feed_id = feed.id;
        title = Some "Article 2";
        url = "https://example.com/a2";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      };
    ]
  in
  let* _ = Db.Article.upsert_many inputs in
  let* result = Db.Article.list_all ~page:1 ~per_page:10 ~unread_only:false in
  match result with
  | Error msg -> Alcotest.fail ("list_all failed: " ^ msg)
  | Ok paginated ->
      Alcotest.(check int) "total is 2" 2 paginated.total;
      Lwt.return_unit

let test_db_article_list_unread_only () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let inputs =
    [
      {
        Model.Article.feed_id = feed.id;
        title = Some "Article 1";
        url = "https://example.com/a1";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      };
      {
        Model.Article.feed_id = feed.id;
        title = Some "Article 2";
        url = "https://example.com/a2";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      };
    ]
  in
  let* _ = Db.Article.upsert_many inputs in
  (* Get articles and mark one as read *)
  let* list_result =
    Db.Article.list_by_feed ~feed_id:feed.id ~page:1 ~per_page:10
  in
  let* () =
    match list_result with
    | Error msg -> Alcotest.fail ("list failed: " ^ msg)
    | Ok paginated -> (
        match paginated.data with
        | article :: _ ->
            let* _ = Db.Article.mark_read ~id:article.id ~read:true in
            Lwt.return_unit
        | [] -> Alcotest.fail "no articles")
  in
  let* result = Db.Article.list_all ~page:1 ~per_page:10 ~unread_only:true in
  match result with
  | Error msg -> Alcotest.fail ("list_all unread failed: " ^ msg)
  | Ok paginated ->
      Alcotest.(check int) "only 1 unread" 1 paginated.total;
      Lwt.return_unit

let test_db_article_mark_read () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let input =
    {
      Model.Article.feed_id = feed.id;
      title = Some "Read Test";
      url = "https://example.com/read-test";
      published_at = None;
      content = None;
      author = None;
      image_url = None;
    }
  in
  let* _ = Db.Article.upsert input in
  let* list_result =
    Db.Article.list_by_feed ~feed_id:feed.id ~page:1 ~per_page:10
  in
  match list_result with
  | Error msg -> Alcotest.fail ("list failed: " ^ msg)
  | Ok paginated -> (
      match paginated.data with
      | [] -> Alcotest.fail "no articles"
      | article :: _ -> (
          Alcotest.(check (option string))
            "initially unread" None article.read_at;
          let* mark_result = Db.Article.mark_read ~id:article.id ~read:true in
          match mark_result with
          | Error msg -> Alcotest.fail ("mark_read failed: " ^ msg)
          | Ok None -> Alcotest.fail "article not found"
          | Ok (Some updated) ->
              Alcotest.(check bool)
                "read_at is set" true
                (Option.is_some updated.read_at);
              Lwt.return_unit))

let test_db_article_mark_unread () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let input =
    {
      Model.Article.feed_id = feed.id;
      title = Some "Unread Test";
      url = "https://example.com/unread-test";
      published_at = None;
      content = None;
      author = None;
      image_url = None;
    }
  in
  let* _ = Db.Article.upsert input in
  let* list_result =
    Db.Article.list_by_feed ~feed_id:feed.id ~page:1 ~per_page:10
  in
  match list_result with
  | Error msg -> Alcotest.fail ("list failed: " ^ msg)
  | Ok paginated -> (
      match paginated.data with
      | [] -> Alcotest.fail "no articles"
      | article :: _ -> (
          (* Mark as read first *)
          let* _ = Db.Article.mark_read ~id:article.id ~read:true in
          (* Then mark as unread *)
          let* mark_result = Db.Article.mark_read ~id:article.id ~read:false in
          match mark_result with
          | Error msg -> Alcotest.fail ("mark_unread failed: " ^ msg)
          | Ok None -> Alcotest.fail "article not found"
          | Ok (Some updated) ->
              Alcotest.(check (option string))
                "read_at is cleared" None updated.read_at;
              Lwt.return_unit))

let test_db_article_mark_all_read () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let inputs =
    [
      {
        Model.Article.feed_id = feed.id;
        title = Some "Article 1";
        url = "https://example.com/a1";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      };
      {
        Model.Article.feed_id = feed.id;
        title = Some "Article 2";
        url = "https://example.com/a2";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      };
    ]
  in
  let* _ = Db.Article.upsert_many inputs in
  let* result = Db.Article.mark_all_read ~feed_id:feed.id in
  match result with
  | Error msg -> Alcotest.fail ("mark_all_read failed: " ^ msg)
  | Ok count ->
      Alcotest.(check int) "marked 2 as read" 2 count;
      (* Verify all are read *)
      let* unread_result =
        Db.Article.list_all ~page:1 ~per_page:10 ~unread_only:true
      in
      (match unread_result with
      | Error msg -> Alcotest.fail ("list unread failed: " ^ msg)
      | Ok paginated ->
          Alcotest.(check int) "no unread articles" 0 paginated.total);
      Lwt.return_unit

let test_db_article_delete () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let input =
    {
      Model.Article.feed_id = feed.id;
      title = Some "Delete Test";
      url = "https://example.com/delete-test";
      published_at = None;
      content = None;
      author = None;
      image_url = None;
    }
  in
  let* _ = Db.Article.upsert input in
  let* list_result =
    Db.Article.list_by_feed ~feed_id:feed.id ~page:1 ~per_page:10
  in
  match list_result with
  | Error msg -> Alcotest.fail ("list failed: " ^ msg)
  | Ok paginated -> (
      match paginated.data with
      | [] -> Alcotest.fail "no articles"
      | article :: _ -> (
          let* delete_result = Db.Article.delete ~id:article.id in
          match delete_result with
          | Error msg -> Alcotest.fail ("delete failed: " ^ msg)
          | Ok false -> Alcotest.fail "delete returned false"
          | Ok true -> (
              let* get_result = Db.Article.get ~id:article.id in
              match get_result with
              | Error msg -> Alcotest.fail ("get after delete failed: " ^ msg)
              | Ok None -> Lwt.return_unit
              | Ok (Some _) -> Alcotest.fail "article still exists")))

let test_db_article_delete_not_found () =
  let* () = setup_test_db () in
  let* result = Db.Article.delete ~id:99999 in
  match result with
  | Error msg -> Alcotest.fail ("delete failed: " ^ msg)
  | Ok false -> Lwt.return_unit
  | Ok true -> Alcotest.fail "expected false for non-existent id"

let db_suite =
  [
    lwt_test "upsert article" test_db_article_upsert;
    lwt_test "upsert many articles" test_db_article_upsert_many;
    lwt_test "upsert duplicate is ignored" test_db_article_upsert_duplicate;
    lwt_test "get article" test_db_article_get;
    lwt_test "list articles by feed" test_db_article_list_by_feed;
    lwt_test "list all articles" test_db_article_list_all;
    lwt_test "list unread articles only" test_db_article_list_unread_only;
    lwt_test "mark article as read" test_db_article_mark_read;
    lwt_test "mark article as unread" test_db_article_mark_unread;
    lwt_test "mark all articles as read" test_db_article_mark_all_read;
    lwt_test "delete article" test_db_article_delete;
    lwt_test "delete article not found" test_db_article_delete_not_found;
  ]

(* ============================================
   Handler Tests
   ============================================ *)

let test_handler_article_list_all () =
  let* () = setup_test_db () in
  let* _person, feed = setup_person_and_feed () in
  let input =
    {
      Model.Article.feed_id = feed.id;
      title = Some "Test Article";
      url = "https://example.com/test";
      published_at = None;
      content = None;
      author = None;
      image_url = None;
    }
  in
  let* _ = Db.Article.upsert input in
  let request = Dream.request ~method_:`GET ~target:"/articles" "" in
  let* response = Handlers.Article.list_all request in
  Alcotest.(check int)
    "status is 200" 200
    (Dream.status response |> Dream.status_to_int);
  let* body = Dream.body response in
  let json = Yojson.Safe.from_string body in
  (match json with
  | `Assoc fields ->
      Alcotest.(check bool) "has data field" true (List.mem_assoc "data" fields);
      Alcotest.(check bool)
        "has total field" true
        (List.mem_assoc "total" fields)
  | _ -> Alcotest.fail "expected JSON object");
  Lwt.return_unit

let test_handler_article_list_all_unread_filter () =
  let* () = setup_test_db () in
  let request =
    Dream.request ~method_:`GET ~target:"/articles?unread=true" ""
  in
  let* response = Handlers.Article.list_all request in
  Alcotest.(check int)
    "status is 200" 200
    (Dream.status response |> Dream.status_to_int);
  Lwt.return_unit

let handler_suite =
  [
    lwt_test "GET /articles returns list" test_handler_article_list_all;
    lwt_test "GET /articles?unread=true filters"
      test_handler_article_list_all_unread_filter;
  ]
