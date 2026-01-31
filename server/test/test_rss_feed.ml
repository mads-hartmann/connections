(* Tests for RSS Feed model and DB *)

open Connections_server
open Test_helpers

let caqti_err err = Format.asprintf "%a" Caqti_error.pp err

let test_db_rss_feed_create () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection_result = Db.Connection.create ~name:"Feed Owner" () in
  match connection_result with
  | Error err -> Alcotest.fail ("create connection failed: " ^ caqti_err err)
  | Ok connection -> (
      let connection_id = Model.Connection.id connection in
      let result =
        Db.Rss_feed.create ~connection_id ~url:"https://example.com/feed.xml"
          ~title:(Some "Test Feed")
      in
      match result with
      | Error err -> Alcotest.fail ("create feed failed: " ^ caqti_err err)
      | Ok None -> Alcotest.fail "create feed returned None"
      | Ok (Some feed) ->
          Alcotest.(check string)
            "url matches" "https://example.com/feed.xml"
            (Model.Rss_feed.url feed);
          Alcotest.(check (option string))
            "title matches" (Some "Test Feed")
            (Model.Rss_feed.title feed);
          Alcotest.(check int)
            "connection_id matches" connection_id
            (Model.Rss_feed.connection_id feed))

let test_db_rss_feed_get () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection, feed = setup_connection_and_feed () in
  let _ = connection in
  let feed_id = Model.Rss_feed.id feed in
  let result = Db.Rss_feed.get ~id:feed_id in
  match result with
  | Error err -> Alcotest.fail ("get failed: " ^ caqti_err err)
  | Ok None -> Alcotest.fail "feed not found"
  | Ok (Some found) ->
      Alcotest.(check int) "id matches" feed_id (Model.Rss_feed.id found);
      Alcotest.(check string)
        "url matches" (Model.Rss_feed.url feed) (Model.Rss_feed.url found)

let test_db_rss_feed_list_by_connection () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection_result = Db.Connection.create ~name:"Feed Owner" () in
  match connection_result with
  | Error err -> Alcotest.fail ("create connection failed: " ^ caqti_err err)
  | Ok connection -> (
      let connection_id = Model.Connection.id connection in
      let _ =
        Db.Rss_feed.create ~connection_id ~url:"https://feed1.com/rss"
          ~title:(Some "Feed 1")
      in
      let _ =
        Db.Rss_feed.create ~connection_id ~url:"https://feed2.com/rss"
          ~title:(Some "Feed 2")
      in
      let result = Db.Rss_feed.list_by_connection ~connection_id ~page:1 ~per_page:10 in
      match result with
      | Error err -> Alcotest.fail ("list failed: " ^ caqti_err err)
      | Ok paginated ->
          Alcotest.(check int) "total is 2" 2 paginated.total;
          Alcotest.(check int) "data length is 2" 2 (List.length paginated.data)
      )

let test_db_rss_feed_delete () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection, feed = setup_connection_and_feed () in
  let _ = connection in
  let feed_id = Model.Rss_feed.id feed in
  let result = Db.Rss_feed.delete ~id:feed_id in
  match result with
  | Error err -> Alcotest.fail ("delete failed: " ^ caqti_err err)
  | Ok false -> Alcotest.fail "delete returned false"
  | Ok true -> (
      let get_result = Db.Rss_feed.get ~id:feed_id in
      match get_result with
      | Error err -> Alcotest.fail ("get after delete failed: " ^ caqti_err err)
      | Ok None -> ()
      | Ok (Some _) -> Alcotest.fail "feed still exists after delete")

let db_suite =
  [
    Alcotest.test_case "create feed" `Quick test_db_rss_feed_create;
    Alcotest.test_case "get feed" `Quick test_db_rss_feed_get;
    Alcotest.test_case "list feeds by connection" `Quick
      test_db_rss_feed_list_by_connection;
    Alcotest.test_case "delete feed" `Quick test_db_rss_feed_delete;
  ]
