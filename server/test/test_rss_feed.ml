(* Tests for RSS Feed model and DB *)

open Connections_server
open Test_helpers

let test_db_rss_feed_create () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let person_result = Db.Person.create ~name:"Feed Owner" in
  match person_result with
  | Error msg -> Alcotest.fail ("create person failed: " ^ msg)
  | Ok person -> (
      let result =
        Db.Rss_feed.create ~person_id:person.id
          ~url:"https://example.com/feed.xml" ~title:(Some "Test Feed")
      in
      match result with
      | Error msg -> Alcotest.fail ("create feed failed: " ^ msg)
      | Ok feed ->
          Alcotest.(check string)
            "url matches" "https://example.com/feed.xml" feed.url;
          Alcotest.(check (option string))
            "title matches" (Some "Test Feed") feed.title;
          Alcotest.(check int) "person_id matches" person.id feed.person_id)

let test_db_rss_feed_get () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let person, feed = setup_person_and_feed () in
  let _ = person in
  let result = Db.Rss_feed.get ~id:feed.id in
  match result with
  | Error msg -> Alcotest.fail ("get failed: " ^ msg)
  | Ok None -> Alcotest.fail "feed not found"
  | Ok (Some found) ->
      Alcotest.(check int) "id matches" feed.id found.id;
      Alcotest.(check string) "url matches" feed.url found.url

let test_db_rss_feed_list_by_person () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let person_result = Db.Person.create ~name:"Feed Owner" in
  match person_result with
  | Error msg -> Alcotest.fail ("create person failed: " ^ msg)
  | Ok person -> (
      let _ =
        Db.Rss_feed.create ~person_id:person.id ~url:"https://feed1.com/rss"
          ~title:(Some "Feed 1")
      in
      let _ =
        Db.Rss_feed.create ~person_id:person.id ~url:"https://feed2.com/rss"
          ~title:(Some "Feed 2")
      in
      let result =
        Db.Rss_feed.list_by_person ~person_id:person.id ~page:1 ~per_page:10
      in
      match result with
      | Error msg -> Alcotest.fail ("list failed: " ^ msg)
      | Ok paginated ->
          Alcotest.(check int) "total is 2" 2 paginated.total;
          Alcotest.(check int) "data length is 2" 2 (List.length paginated.data)
      )

let test_db_rss_feed_delete () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let person, feed = setup_person_and_feed () in
  let _ = person in
  let result = Db.Rss_feed.delete ~id:feed.id in
  match result with
  | Error msg -> Alcotest.fail ("delete failed: " ^ msg)
  | Ok false -> Alcotest.fail "delete returned false"
  | Ok true -> (
      let get_result = Db.Rss_feed.get ~id:feed.id in
      match get_result with
      | Error msg -> Alcotest.fail ("get after delete failed: " ^ msg)
      | Ok None -> ()
      | Ok (Some _) -> Alcotest.fail "feed still exists after delete")

let db_suite =
  [
    Alcotest.test_case "create feed" `Quick test_db_rss_feed_create;
    Alcotest.test_case "get feed" `Quick test_db_rss_feed_get;
    Alcotest.test_case "list feeds by person" `Quick
      test_db_rss_feed_list_by_person;
    Alcotest.test_case "delete feed" `Quick test_db_rss_feed_delete;
  ]
