(* Tests for Person model, DB, and handlers *)

open Lwt.Syntax
open Connections_server
open Test_helpers

(* ============================================
   JSON Serialization Tests
   ============================================ *)

let test_person_to_json () =
  let person = { Model.Person.id = 1; name = "Alice" } in
  let json = Model.Person.to_json person in
  let expected = `Assoc [ ("id", `Int 1); ("name", `String "Alice") ] in
  Alcotest.(check string)
    "person serializes correctly"
    (Yojson.Safe.to_string expected)
    (Yojson.Safe.to_string json)

let test_person_of_json () =
  let json = `Assoc [ ("id", `Int 1); ("name", `String "Bob") ] in
  let person = Model.Person.of_json json in
  Alcotest.(check int) "id matches" 1 person.id;
  Alcotest.(check string) "name matches" "Bob" person.name

let test_person_error_to_json () =
  let json = Model.Person.error_to_json "Something went wrong" in
  let expected = `Assoc [ ("error", `String "Something went wrong") ] in
  Alcotest.(check string)
    "error serializes correctly"
    (Yojson.Safe.to_string expected)
    (Yojson.Safe.to_string json)

let test_person_paginated_to_json () =
  let alice : Model.Person.t = { id = 1; name = "Alice" } in
  let bob : Model.Person.t = { id = 2; name = "Bob" } in
  let response = Model.Shared.Paginated.make ~data:[ alice; bob ] ~page:1 ~per_page:10 ~total:2 in
  let json = Model.Person.paginated_to_json response in
  match json with
  | `Assoc fields ->
      Alcotest.(check bool) "has data field" true (List.mem_assoc "data" fields);
      Alcotest.(check bool) "has page field" true (List.mem_assoc "page" fields);
      Alcotest.(check bool)
        "has total field" true
        (List.mem_assoc "total" fields)
  | _ -> Alcotest.fail "expected JSON object"

let test_person_paginated_with_counts_to_json () =
  let data =
    [
      { Model.Person.id = 1; name = "Alice"; feed_count = 2; article_count = 10 };
      { Model.Person.id = 2; name = "Bob"; feed_count = 1; article_count = 5 };
    ]
  in
  let response = Model.Shared.Paginated.make ~data ~page:1 ~per_page:10 ~total:2 in
  let json = Model.Person.paginated_with_counts_to_json response in
  match json with
  | `Assoc fields -> (
      Alcotest.(check bool) "has data field" true (List.mem_assoc "data" fields);
      Alcotest.(check bool) "has page field" true (List.mem_assoc "page" fields);
      Alcotest.(check bool)
        "has total field" true
        (List.mem_assoc "total" fields);
      match List.assoc "data" fields with
      | `List [ `Assoc person1; _ ] ->
          Alcotest.(check bool)
            "person has feed_count" true
            (List.mem_assoc "feed_count" person1);
          Alcotest.(check bool)
            "person has article_count" true
            (List.mem_assoc "article_count" person1)
      | _ -> Alcotest.fail "expected data to be a list of objects")
  | _ -> Alcotest.fail "expected JSON object"

let json_suite =
  [
    sync_test "Person.to_json" test_person_to_json;
    sync_test "Person.of_json" test_person_of_json;
    sync_test "Person.error_to_json" test_person_error_to_json;
    sync_test "Person.paginated_to_json" test_person_paginated_to_json;
    sync_test "Person.paginated_with_counts_to_json"
      test_person_paginated_with_counts_to_json;
  ]

(* ============================================
   Database Tests
   ============================================ *)

let test_db_person_create () =
  let* () = setup_test_db () in
  let* result = Db.Person.create ~name:"Test Person" in
  match result with
  | Error msg -> Alcotest.fail ("create failed: " ^ msg)
  | Ok person ->
      Alcotest.(check string) "name matches" "Test Person" person.name;
      Alcotest.(check bool) "id is positive" true (person.id > 0);
      Lwt.return_unit

let test_db_person_get () =
  let* () = setup_test_db () in
  let* create_result = Db.Person.create ~name:"Get Test" in
  match create_result with
  | Error msg -> Alcotest.fail ("create failed: " ^ msg)
  | Ok created -> (
      let* get_result = Db.Person.get ~id:created.id in
      match get_result with
      | Error msg -> Alcotest.fail ("get failed: " ^ msg)
      | Ok None -> Alcotest.fail "person not found"
      | Ok (Some person) ->
          Alcotest.(check int) "id matches" created.id person.id;
          Alcotest.(check string) "name matches" "Get Test" person.name;
          Lwt.return_unit)

let test_db_person_get_not_found () =
  let* () = setup_test_db () in
  let* result = Db.Person.get ~id:99999 in
  match result with
  | Error msg -> Alcotest.fail ("get failed: " ^ msg)
  | Ok None -> Lwt.return_unit
  | Ok (Some _) -> Alcotest.fail "expected None for non-existent id"

let test_db_person_list () =
  let* () = setup_test_db () in
  let* _ = Db.Person.create ~name:"Alice" in
  let* _ = Db.Person.create ~name:"Bob" in
  let* _ = Db.Person.create ~name:"Charlie" in
  let* result = Db.Person.list ~page:1 ~per_page:10 () in
  match result with
  | Error msg -> Alcotest.fail ("list failed: " ^ msg)
  | Ok paginated ->
      Alcotest.(check int) "total is 3" 3 paginated.total;
      Alcotest.(check int) "data length is 3" 3 (List.length paginated.data);
      Alcotest.(check int) "page is 1" 1 paginated.page;
      Lwt.return_unit

let test_db_person_list_pagination () =
  let* () = setup_test_db () in
  let* _ = Db.Person.create ~name:"Person 1" in
  let* _ = Db.Person.create ~name:"Person 2" in
  let* _ = Db.Person.create ~name:"Person 3" in
  let* result = Db.Person.list ~page:1 ~per_page:2 () in
  match result with
  | Error msg -> Alcotest.fail ("list failed: " ^ msg)
  | Ok paginated ->
      Alcotest.(check int) "total is 3" 3 paginated.total;
      Alcotest.(check int) "data length is 2" 2 (List.length paginated.data);
      Alcotest.(check int) "total_pages is 2" 2 paginated.total_pages;
      Lwt.return_unit

let test_db_person_list_with_query () =
  let* () = setup_test_db () in
  let* _ = Db.Person.create ~name:"Alice Smith" in
  let* _ = Db.Person.create ~name:"Bob Jones" in
  let* _ = Db.Person.create ~name:"Alice Johnson" in
  let* result = Db.Person.list ~page:1 ~per_page:10 ~query:"Alice" () in
  match result with
  | Error msg -> Alcotest.fail ("list failed: " ^ msg)
  | Ok paginated ->
      Alcotest.(check int) "total is 2" 2 paginated.total;
      Alcotest.(check int) "data length is 2" 2 (List.length paginated.data);
      Lwt.return_unit

let test_db_person_update () =
  let* () = setup_test_db () in
  let* create_result = Db.Person.create ~name:"Original Name" in
  match create_result with
  | Error msg -> Alcotest.fail ("create failed: " ^ msg)
  | Ok created -> (
      let* update_result =
        Db.Person.update ~id:created.id ~name:"Updated Name"
      in
      match update_result with
      | Error msg -> Alcotest.fail ("update failed: " ^ msg)
      | Ok None -> Alcotest.fail "person not found for update"
      | Ok (Some updated) ->
          Alcotest.(check string) "name updated" "Updated Name" updated.name;
          Lwt.return_unit)

let test_db_person_update_not_found () =
  let* () = setup_test_db () in
  let* result = Db.Person.update ~id:99999 ~name:"New Name" in
  match result with
  | Error msg -> Alcotest.fail ("update failed: " ^ msg)
  | Ok None -> Lwt.return_unit
  | Ok (Some _) -> Alcotest.fail "expected None for non-existent id"

let test_db_person_delete () =
  let* () = setup_test_db () in
  let* create_result = Db.Person.create ~name:"To Delete" in
  match create_result with
  | Error msg -> Alcotest.fail ("create failed: " ^ msg)
  | Ok created -> (
      let* delete_result = Db.Person.delete ~id:created.id in
      match delete_result with
      | Error msg -> Alcotest.fail ("delete failed: " ^ msg)
      | Ok false -> Alcotest.fail "delete returned false"
      | Ok true -> (
          let* get_result = Db.Person.get ~id:created.id in
          match get_result with
          | Error msg -> Alcotest.fail ("get after delete failed: " ^ msg)
          | Ok None -> Lwt.return_unit
          | Ok (Some _) -> Alcotest.fail "person still exists after delete"))

let test_db_person_delete_not_found () =
  let* () = setup_test_db () in
  let* result = Db.Person.delete ~id:99999 in
  match result with
  | Error msg -> Alcotest.fail ("delete failed: " ^ msg)
  | Ok false -> Lwt.return_unit
  | Ok true -> Alcotest.fail "expected false for non-existent id"

let test_db_person_list_with_counts () =
  let* () = setup_test_db () in
  let* person_result = Db.Person.create ~name:"Alice" in
  match person_result with
  | Error msg -> Alcotest.fail ("create person failed: " ^ msg)
  | Ok person -> (
      (* Create 2 feeds for Alice *)
      let* _ =
        Db.Rss_feed.create ~person_id:person.id ~url:"https://feed1.com/rss"
          ~title:(Some "Feed 1")
      in
      let* feed2_result =
        Db.Rss_feed.create ~person_id:person.id ~url:"https://feed2.com/rss"
          ~title:(Some "Feed 2")
      in
      match feed2_result with
      | Error msg -> Alcotest.fail ("create feed failed: " ^ msg)
      | Ok feed2 -> (
          (* Create 3 articles in feed2 *)
          let* _ =
            Db.Article.upsert
              {
                Model.Article.feed_id = feed2.id;
                title = Some "Article 1";
                url = "https://example.com/article1";
                published_at = None;
                content = None;
                author = None;
                image_url = None;
              }
          in
          let* _ =
            Db.Article.upsert
              {
                Model.Article.feed_id = feed2.id;
                title = Some "Article 2";
                url = "https://example.com/article2";
                published_at = None;
                content = None;
                author = None;
                image_url = None;
              }
          in
          let* _ =
            Db.Article.upsert
              {
                Model.Article.feed_id = feed2.id;
                title = Some "Article 3";
                url = "https://example.com/article3";
                published_at = None;
                content = None;
                author = None;
                image_url = None;
              }
          in
          let* result = Db.Person.list_with_counts ~page:1 ~per_page:10 () in
          match result with
          | Error msg -> Alcotest.fail ("list_with_counts failed: " ^ msg)
          | Ok paginated ->
              Alcotest.(check int) "total is 1" 1 paginated.total;
              Alcotest.(check int)
                "data length is 1" 1
                (List.length paginated.data);
              let alice = List.hd paginated.data in
              Alcotest.(check string) "name is Alice" "Alice" alice.name;
              Alcotest.(check int) "feed_count is 2" 2 alice.feed_count;
              Alcotest.(check int) "article_count is 3" 3 alice.article_count;
              Lwt.return_unit))

let test_db_person_list_with_counts_no_feeds () =
  let* () = setup_test_db () in
  let* _ = Db.Person.create ~name:"Bob" in
  let* result = Db.Person.list_with_counts ~page:1 ~per_page:10 () in
  match result with
  | Error msg -> Alcotest.fail ("list_with_counts failed: " ^ msg)
  | Ok paginated ->
      Alcotest.(check int) "total is 1" 1 paginated.total;
      let bob = List.hd paginated.data in
      Alcotest.(check string) "name is Bob" "Bob" bob.name;
      Alcotest.(check int) "feed_count is 0" 0 bob.feed_count;
      Alcotest.(check int) "article_count is 0" 0 bob.article_count;
      Lwt.return_unit

let test_db_person_list_with_counts_query () =
  let* () = setup_test_db () in
  let* _ = Db.Person.create ~name:"Alice Smith" in
  let* _ = Db.Person.create ~name:"Bob Jones" in
  let* result =
    Db.Person.list_with_counts ~page:1 ~per_page:10 ~query:"Alice" ()
  in
  match result with
  | Error msg -> Alcotest.fail ("list_with_counts failed: " ^ msg)
  | Ok paginated ->
      Alcotest.(check int) "total is 1" 1 paginated.total;
      Alcotest.(check int) "data length is 1" 1 (List.length paginated.data);
      let alice = List.hd paginated.data in
      Alcotest.(check string) "name is Alice Smith" "Alice Smith" alice.name;
      Lwt.return_unit

let db_suite =
  [
    lwt_test "create person" test_db_person_create;
    lwt_test "get person" test_db_person_get;
    lwt_test "get person not found" test_db_person_get_not_found;
    lwt_test "list persons" test_db_person_list;
    lwt_test "list persons with pagination" test_db_person_list_pagination;
    lwt_test "list persons with query" test_db_person_list_with_query;
    lwt_test "update person" test_db_person_update;
    lwt_test "update person not found" test_db_person_update_not_found;
    lwt_test "delete person" test_db_person_delete;
    lwt_test "delete person not found" test_db_person_delete_not_found;
    lwt_test "list persons with counts" test_db_person_list_with_counts;
    lwt_test "list persons with counts (no feeds)"
      test_db_person_list_with_counts_no_feeds;
    lwt_test "list persons with counts (query)"
      test_db_person_list_with_counts_query;
  ]

(* ============================================
   Handler Tests
   ============================================ *)

let test_handler_person_list () =
  let* () = setup_test_db () in
  let* _ = Db.Person.create ~name:"Test Person" in
  let request = Dream.request ~method_:`GET ~target:"/persons" "" in
  let* response = Handlers.Person.list request in
  Alcotest.(check int)
    "status is 200" 200
    (Dream.status response |> Dream.status_to_int);
  let* body = Dream.body response in
  let json = Yojson.Safe.from_string body in
  (match json with
  | `Assoc fields -> (
      Alcotest.(check bool) "has data field" true (List.mem_assoc "data" fields);
      match List.assoc "data" fields with
      | `List [ `Assoc person_fields ] ->
          Alcotest.(check bool)
            "person has feed_count" true
            (List.mem_assoc "feed_count" person_fields);
          Alcotest.(check bool)
            "person has article_count" true
            (List.mem_assoc "article_count" person_fields)
      | _ -> Alcotest.fail "expected data to be a list with one person")
  | _ -> Alcotest.fail "expected JSON object");
  Lwt.return_unit

let test_handler_person_create () =
  let* () = setup_test_db () in
  let body = {|{"name": "New Person"}|} in
  let request = Dream.request ~method_:`POST ~target:"/persons" body in
  let* response = Handlers.Person.create request in
  Alcotest.(check int)
    "status is 201" 201
    (Dream.status response |> Dream.status_to_int);
  let* body = Dream.body response in
  let json = Yojson.Safe.from_string body in
  (match json with
  | `Assoc fields ->
      Alcotest.(check bool) "has id field" true (List.mem_assoc "id" fields);
      Alcotest.(check bool) "has name field" true (List.mem_assoc "name" fields)
  | _ -> Alcotest.fail "expected JSON object");
  Lwt.return_unit

let test_handler_person_create_empty_name () =
  let* () = setup_test_db () in
  let body = {|{"name": ""}|} in
  let request = Dream.request ~method_:`POST ~target:"/persons" body in
  let* response = Handlers.Person.create request in
  Alcotest.(check int)
    "status is 400" 400
    (Dream.status response |> Dream.status_to_int);
  Lwt.return_unit

let test_handler_person_create_invalid_json () =
  let* () = setup_test_db () in
  let body = "not valid json" in
  let request = Dream.request ~method_:`POST ~target:"/persons" body in
  let* response = Handlers.Person.create request in
  Alcotest.(check int)
    "status is 400" 400
    (Dream.status response |> Dream.status_to_int);
  Lwt.return_unit

let test_handler_person_create_missing_name () =
  let* () = setup_test_db () in
  let body = {|{"other": "field"}|} in
  let request = Dream.request ~method_:`POST ~target:"/persons" body in
  let* response = Handlers.Person.create request in
  Alcotest.(check int)
    "status is 400" 400
    (Dream.status response |> Dream.status_to_int);
  Lwt.return_unit

let test_handler_json_content_type () =
  let* () = setup_test_db () in
  let request = Dream.request ~method_:`GET ~target:"/persons" "" in
  let* response = Handlers.Person.list request in
  let content_type = Dream.header response "Content-Type" in
  Alcotest.(check (option string))
    "content-type is application/json" (Some "application/json") content_type;
  Lwt.return_unit

let handler_suite =
  [
    lwt_test "GET /persons returns list" test_handler_person_list;
    lwt_test "POST /persons creates person" test_handler_person_create;
    lwt_test "POST /persons with empty name returns 400"
      test_handler_person_create_empty_name;
    lwt_test "POST /persons with invalid JSON returns 400"
      test_handler_person_create_invalid_json;
    lwt_test "POST /persons with missing name returns 400"
      test_handler_person_create_missing_name;
    lwt_test "responses have JSON content-type" test_handler_json_content_type;
  ]
