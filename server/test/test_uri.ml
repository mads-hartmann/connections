(* Tests for URI model and DB *)

open Connections_server
open Test_helpers

(* ============================================
   JSON Serialization Tests
   ============================================ *)

let test_uri_to_json () =
  let uri =
    Model.Uri_entry.create ~id:1 ~feed_id:(Some 1) ~connection_id:None
      ~connection_name:None ~kind:Model.Uri_kind.Blog
      ~title:(Some "Test URI") ~url:"https://example.com/article"
      ~published_at:(Some "2024-01-01 12:00:00")
      ~content:(Some "URI content") ~author:(Some "John Doe")
      ~image_url:None ~created_at:"2024-01-01 12:00:00" ~read_at:None
      ~read_later_at:None ~tags:[] ~og_title:None ~og_description:None
      ~og_image:None ~og_site_name:None ~og_fetched_at:None ~og_fetch_error:None
  in
  let json = Model.Uri_entry.to_json uri in
  match json with
  | `Assoc fields ->
      Alcotest.(check bool) "has id field" true (List.mem_assoc "id" fields);
      Alcotest.(check bool) "has url field" true (List.mem_assoc "url" fields);
      Alcotest.(check bool) "has kind field" true (List.mem_assoc "kind" fields);
      Alcotest.(check bool)
        "has title field" true
        (List.mem_assoc "title" fields)
  | _ -> Alcotest.fail "expected JSON object"

let json_suite =
  [ Alcotest.test_case "Uri.to_json" `Quick test_uri_to_json ]

(* ============================================
   Database Tests
   ============================================ *)

let test_db_uri_upsert () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection, feed = setup_connection_and_feed () in
  let feed_id = Model.Rss_feed.id feed in
  let connection_id = Some (Model.Connection.id connection) in
  let result =
    Db.Uri_store.upsert ~feed_id ~connection_id ~kind:Model.Uri_kind.Blog
      ~title:(Some "Test URI") ~url:"https://example.com/article1"
      ~published_at:None ~content:(Some "Content") ~author:(Some "Author")
      ~image_url:None
  in
  match result with
  | Error err ->
      Alcotest.fail (Format.asprintf "upsert failed: %a" Caqti_error.pp err)
  | Ok _ -> ()

let test_db_uri_create () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection, _ = setup_connection_and_feed () in
  let connection_id = Some (Model.Connection.id connection) in
  let result =
    Db.Uri_store.create ~connection_id ~kind:Model.Uri_kind.Video
      ~url:"https://youtube.com/watch?v=123" ~title:(Some "Test Video")
  in
  match result with
  | Error err ->
      Alcotest.fail (Format.asprintf "create failed: %a" Caqti_error.pp err)
  | Ok uri ->
      Alcotest.(check string) "kind is video" "video"
        (Model.Uri_kind.to_string (Model.Uri_entry.kind uri));
      Alcotest.(check (option int)) "connection_id matches" connection_id
        (Model.Uri_entry.connection_id uri);
      Alcotest.(check (option int)) "feed_id is None" None
        (Model.Uri_entry.feed_id uri)

let test_db_uri_list_by_feed () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection, feed = setup_connection_and_feed () in
  let feed_id = Model.Rss_feed.id feed in
  let connection_id = Some (Model.Connection.id connection) in
  let _ =
    Db.Uri_store.upsert ~feed_id ~connection_id ~kind:Model.Uri_kind.Blog
      ~title:(Some "URI 1") ~url:"https://example.com/a1"
      ~published_at:None ~content:None ~author:None ~image_url:None
  in
  let _ =
    Db.Uri_store.upsert ~feed_id ~connection_id ~kind:Model.Uri_kind.Blog
      ~title:(Some "URI 2") ~url:"https://example.com/a2"
      ~published_at:None ~content:None ~author:None ~image_url:None
  in
  let result = Db.Uri_store.list_by_feed ~feed_id ~page:1 ~per_page:10 in
  match result with
  | Error err ->
      Alcotest.fail (Format.asprintf "list failed: %a" Caqti_error.pp err)
  | Ok paginated ->
      Alcotest.(check int) "total is 2" 2 paginated.total;
      Alcotest.(check int) "data length is 2" 2 (List.length paginated.data)

let test_db_uri_mark_read () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection, feed = setup_connection_and_feed () in
  let feed_id = Model.Rss_feed.id feed in
  let connection_id = Some (Model.Connection.id connection) in
  let _ =
    Db.Uri_store.upsert ~feed_id ~connection_id ~kind:Model.Uri_kind.Blog
      ~title:(Some "To Read") ~url:"https://example.com/read"
      ~published_at:None ~content:None ~author:None ~image_url:None
  in
  (* Get the URI to find its ID *)
  let list_result = Db.Uri_store.list_by_feed ~feed_id ~page:1 ~per_page:10 in
  match list_result with
  | Error err ->
      Alcotest.fail (Format.asprintf "list failed: %a" Caqti_error.pp err)
  | Ok paginated -> (
      let uri = List.hd paginated.data in
      let mark_result =
        Db.Uri_store.mark_read ~id:(Model.Uri_entry.id uri) ~read:true
      in
      match mark_result with
      | Error err ->
          Alcotest.fail
            (Format.asprintf "mark_read failed: %a" Caqti_error.pp err)
      | Ok None -> Alcotest.fail "URI not found"
      | Ok (Some updated) ->
          Alcotest.(check bool)
            "read_at is set" true
            (Option.is_some (Model.Uri_entry.read_at updated)))

let db_suite =
  [
    Alcotest.test_case "upsert URI" `Quick test_db_uri_upsert;
    Alcotest.test_case "create URI" `Quick test_db_uri_create;
    Alcotest.test_case "list URIs by feed" `Quick test_db_uri_list_by_feed;
    Alcotest.test_case "mark URI read" `Quick test_db_uri_mark_read;
  ]

(* Handler tests are stubbed *)
let handler_suite = []
