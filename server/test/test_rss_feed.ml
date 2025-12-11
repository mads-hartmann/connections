(* Tests for RSS Feed model and DB *)

open Lwt.Syntax
open Connections_server
open Test_helpers

(* ============================================
   Database Tests
   ============================================ *)

let test_db_rss_feed_create () =
  let* () = setup_test_db () in
  let* person_result = Db.Person.create ~name:"Feed Owner" in
  match person_result with
  | Error msg -> Alcotest.fail ("create person failed: " ^ msg)
  | Ok person -> (
      let* feed_result =
        Db.Rss_feed.create ~person_id:person.id
          ~url:"https://example.com/feed.xml" ~title:(Some "My Feed")
      in
      match feed_result with
      | Error msg -> Alcotest.fail ("create feed failed: " ^ msg)
      | Ok feed ->
          Alcotest.(check int) "person_id matches" person.id feed.person_id;
          Alcotest.(check string)
            "url matches" "https://example.com/feed.xml" feed.url;
          Alcotest.(check (option string))
            "title matches" (Some "My Feed") feed.title;
          Alcotest.(check bool) "id is positive" true (feed.id > 0);
          Lwt.return_unit)

let test_db_rss_feed_create_no_title () =
  let* () = setup_test_db () in
  let* person_result = Db.Person.create ~name:"Feed Owner" in
  match person_result with
  | Error msg -> Alcotest.fail ("create person failed: " ^ msg)
  | Ok person -> (
      let* feed_result =
        Db.Rss_feed.create ~person_id:person.id
          ~url:"https://example.com/feed.xml" ~title:None
      in
      match feed_result with
      | Error msg -> Alcotest.fail ("create feed failed: " ^ msg)
      | Ok feed ->
          Alcotest.(check (option string)) "title is None" None feed.title;
          Lwt.return_unit)

let test_db_rss_feed_get () =
  let* () = setup_test_db () in
  let* person_result = Db.Person.create ~name:"Feed Owner" in
  match person_result with
  | Error msg -> Alcotest.fail ("create person failed: " ^ msg)
  | Ok person -> (
      let* create_result =
        Db.Rss_feed.create ~person_id:person.id
          ~url:"https://example.com/feed.xml" ~title:(Some "Test Feed")
      in
      match create_result with
      | Error msg -> Alcotest.fail ("create feed failed: " ^ msg)
      | Ok created -> (
          let* get_result = Db.Rss_feed.get ~id:created.id in
          match get_result with
          | Error msg -> Alcotest.fail ("get feed failed: " ^ msg)
          | Ok None -> Alcotest.fail "feed not found"
          | Ok (Some feed) ->
              Alcotest.(check int) "id matches" created.id feed.id;
              Alcotest.(check string)
                "url matches" "https://example.com/feed.xml" feed.url;
              Lwt.return_unit))

let test_db_rss_feed_list_by_person () =
  let* () = setup_test_db () in
  let* person_result = Db.Person.create ~name:"Feed Owner" in
  match person_result with
  | Error msg -> Alcotest.fail ("create person failed: " ^ msg)
  | Ok person -> (
      let* _ =
        Db.Rss_feed.create ~person_id:person.id
          ~url:"https://example.com/feed1.xml" ~title:(Some "Feed 1")
      in
      let* _ =
        Db.Rss_feed.create ~person_id:person.id
          ~url:"https://example.com/feed2.xml" ~title:(Some "Feed 2")
      in
      let* result =
        Db.Rss_feed.list_by_person ~person_id:person.id ~page:1 ~per_page:10
      in
      match result with
      | Error msg -> Alcotest.fail ("list feeds failed: " ^ msg)
      | Ok paginated ->
          Alcotest.(check int) "total is 2" 2 paginated.total;
          Alcotest.(check int) "data length is 2" 2 (List.length paginated.data);
          Lwt.return_unit)

let test_db_rss_feed_update () =
  let* () = setup_test_db () in
  let* person_result = Db.Person.create ~name:"Feed Owner" in
  match person_result with
  | Error msg -> Alcotest.fail ("create person failed: " ^ msg)
  | Ok person -> (
      let* create_result =
        Db.Rss_feed.create ~person_id:person.id
          ~url:"https://example.com/old.xml" ~title:(Some "Old Title")
      in
      match create_result with
      | Error msg -> Alcotest.fail ("create feed failed: " ^ msg)
      | Ok created -> (
          let* update_result =
            Db.Rss_feed.update ~id:created.id
              ~url:(Some "https://example.com/new.xml")
              ~title:(Some "New Title")
          in
          match update_result with
          | Error msg -> Alcotest.fail ("update feed failed: " ^ msg)
          | Ok None -> Alcotest.fail "feed not found for update"
          | Ok (Some updated) ->
              Alcotest.(check string)
                "url updated" "https://example.com/new.xml" updated.url;
              Alcotest.(check (option string))
                "title updated" (Some "New Title") updated.title;
              Lwt.return_unit))

let test_db_rss_feed_delete () =
  let* () = setup_test_db () in
  let* person_result = Db.Person.create ~name:"Feed Owner" in
  match person_result with
  | Error msg -> Alcotest.fail ("create person failed: " ^ msg)
  | Ok person -> (
      let* create_result =
        Db.Rss_feed.create ~person_id:person.id
          ~url:"https://example.com/feed.xml" ~title:None
      in
      match create_result with
      | Error msg -> Alcotest.fail ("create feed failed: " ^ msg)
      | Ok created -> (
          let* delete_result = Db.Rss_feed.delete ~id:created.id in
          match delete_result with
          | Error msg -> Alcotest.fail ("delete feed failed: " ^ msg)
          | Ok false -> Alcotest.fail "delete returned false"
          | Ok true -> (
              let* get_result = Db.Rss_feed.get ~id:created.id in
              match get_result with
              | Error msg -> Alcotest.fail ("get after delete failed: " ^ msg)
              | Ok None -> Lwt.return_unit
              | Ok (Some _) -> Alcotest.fail "feed still exists after delete")))

let db_suite =
  [
    lwt_test "create rss feed" test_db_rss_feed_create;
    lwt_test "create rss feed without title" test_db_rss_feed_create_no_title;
    lwt_test "get rss feed" test_db_rss_feed_get;
    lwt_test "list rss feeds by person" test_db_rss_feed_list_by_person;
    lwt_test "update rss feed" test_db_rss_feed_update;
    lwt_test "delete rss feed" test_db_rss_feed_delete;
  ]
