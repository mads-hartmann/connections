(* Shared test helpers *)

open Connections_server

let caqti_err err = Format.asprintf "%a" Caqti_error.pp err

(* Setup in-memory database for tests - requires Eio context *)
let setup_test_db ~sw ~stdenv =
  Db.Pool.init ~sw ~stdenv ":memory:";
  Db.Pool.apply_schema ()

(* Helper to run tests within Eio context *)
let with_eio f =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw -> f ~sw ~env

(* Helper to create a person and feed for article tests *)
let setup_person_and_feed () =
  let person_result = Db.Person.create ~name:"Article Owner" in
  match person_result with
  | Error err -> Alcotest.fail ("create person failed: " ^ caqti_err err)
  | Ok person -> (
      let feed_result =
        Db.Rss_feed.create ~person_id:(Model.Person.id person)
          ~url:"https://example.com/feed.xml" ~title:(Some "Test Feed")
      in
      match feed_result with
      | Error err -> Alcotest.fail ("create feed failed: " ^ caqti_err err)
      | Ok None -> Alcotest.fail "create feed returned None"
      | Ok (Some feed) -> (person, feed))
