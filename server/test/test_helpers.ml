(* Shared test helpers *)

open Lwt.Syntax
open Connections_server

(* Helper to wrap synchronous tests for Alcotest_lwt *)
let sync_test name f =
  Alcotest_lwt.test_case name `Quick (fun _sw () ->
      f ();
      Lwt.return_unit)

(* Helper to run Lwt tests *)
let lwt_test name f = Alcotest_lwt.test_case name `Quick (fun _sw () -> f ())

(* Setup in-memory database for tests *)
let setup_test_db () =
  let* () = Db.Pool.init ":memory:" in
  let* () = Db.Person.init_table () in
  let* () = Db.Rss_feed.init_table () in
  let* () = Db.Article.init_table () in
  Lwt.return_unit

(* Helper to create a person and feed for article tests *)
let setup_person_and_feed () =
  let* person_result = Db.Person.create ~name:"Article Owner" in
  match person_result with
  | Error msg -> Alcotest.fail ("create person failed: " ^ msg)
  | Ok person -> (
      let* feed_result =
        Db.Rss_feed.create ~person_id:person.id
          ~url:"https://example.com/feed.xml" ~title:(Some "Test Feed")
      in
      match feed_result with
      | Error msg -> Alcotest.fail ("create feed failed: " ^ msg)
      | Ok feed -> Lwt.return (person, feed))
