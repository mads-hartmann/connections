(* Shared test helpers *)

open Connections_server

let caqti_err err = Format.asprintf "%a" Caqti_error.pp err

let find_workspace_root () =
  let rec find dir =
    let dune_project = Filename.concat dir "dune-project" in
    if Sys.file_exists dune_project then Some dir
    else
      let parent = Filename.dirname dir in
      if parent = dir then None else find parent
  in
  find (Sys.getcwd ())

let workspace_root =
  match find_workspace_root () with
  | Some root -> root
  | None -> failwith "Could not find workspace root (dune-project)"

let schema_path = Filename.concat workspace_root "server/lib/db/schema.sql"

(* Setup in-memory database for tests - requires Eio context *)
let setup_test_db ~sw ~stdenv =
  Db.Pool.init ~sw ~stdenv ":memory:";
  Db.Pool.apply_schema ~schema_path

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
        Db.Rss_feed.create ~person_id:person.id
          ~url:"https://example.com/feed.xml" ~title:(Some "Test Feed")
      in
      match feed_result with
      | Error err -> Alcotest.fail ("create feed failed: " ^ caqti_err err)
      | Ok None -> Alcotest.fail "create feed returned None"
      | Ok (Some feed) -> (person, feed))
