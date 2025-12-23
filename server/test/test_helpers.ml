(* Shared test helpers *)

open Connections_server

(* Setup in-memory database for tests - requires Eio context *)
let setup_test_db ~sw ~stdenv =
  Db.Pool.init ~sw ~stdenv ":memory:";
  Db.Person.init_table ();
  Db.Rss_feed.init_table ();
  Db.Article.init_table ();
  Db.Category.init_table ()

(* Helper to run tests within Eio context *)
let with_eio f =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw -> f ~sw ~env

(* Helper to create a person and feed for article tests *)
let setup_person_and_feed () =
  let person_result = Db.Person.create ~name:"Article Owner" in
  match person_result with
  | Error msg -> Alcotest.fail ("create person failed: " ^ msg)
  | Ok person -> (
      let feed_result =
        Db.Rss_feed.create ~person_id:person.id
          ~url:"https://example.com/feed.xml" ~title:(Some "Test Feed")
      in
      match feed_result with
      | Error msg -> Alcotest.fail ("create feed failed: " ^ msg)
      | Ok feed -> (person, feed))
