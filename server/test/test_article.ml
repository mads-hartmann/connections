(* Tests for Article model and DB *)

open Connections_server
open Test_helpers

(* ============================================
   JSON Serialization Tests
   ============================================ *)

let test_article_to_json () =
  let article =
    Model.Article.create ~id:1 ~feed_id:1 ~person_id:None ~person_name:None
      ~title:(Some "Test Article") ~url:"https://example.com/article"
      ~published_at:(Some "2024-01-01 12:00:00")
      ~content:(Some "Article content") ~author:(Some "John Doe")
      ~image_url:None ~created_at:"2024-01-01 12:00:00" ~read_at:None
      ~read_later_at:None ~tags:[] ~og_title:None ~og_description:None
      ~og_image:None ~og_site_name:None ~og_fetched_at:None ~og_fetch_error:None
  in
  let json = Model.Article.to_json article in
  match json with
  | `Assoc fields ->
      Alcotest.(check bool) "has id field" true (List.mem_assoc "id" fields);
      Alcotest.(check bool) "has url field" true (List.mem_assoc "url" fields);
      Alcotest.(check bool)
        "has title field" true
        (List.mem_assoc "title" fields)
  | _ -> Alcotest.fail "expected JSON object"

let json_suite =
  [ Alcotest.test_case "Article.to_json" `Quick test_article_to_json ]

(* ============================================
   Database Tests
   ============================================ *)

let test_db_article_upsert () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let person, feed = setup_person_and_feed () in
  let feed_id = Model.Rss_feed.id feed in
  let person_id = Some (Model.Person.id person) in
  let input : Db.Article.create_input =
    {
      feed_id;
      person_id;
      title = Some "Test Article";
      url = "https://example.com/article1";
      published_at = None;
      content = Some "Content";
      author = Some "Author";
      image_url = None;
    }
  in
  let result = Db.Article.upsert input in
  match result with
  | Error err ->
      Alcotest.fail (Format.asprintf "upsert failed: %a" Caqti_error.pp err)
  | Ok () -> ()

let test_db_article_list_by_feed () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let person, feed = setup_person_and_feed () in
  let feed_id = Model.Rss_feed.id feed in
  let person_id = Some (Model.Person.id person) in
  let _ =
    Db.Article.upsert
      {
        feed_id;
        person_id;
        title = Some "Article 1";
        url = "https://example.com/a1";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      }
  in
  let _ =
    Db.Article.upsert
      {
        feed_id;
        person_id;
        title = Some "Article 2";
        url = "https://example.com/a2";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      }
  in
  let result = Db.Article.list_by_feed ~feed_id ~page:1 ~per_page:10 in
  match result with
  | Error err ->
      Alcotest.fail (Format.asprintf "list failed: %a" Caqti_error.pp err)
  | Ok paginated ->
      Alcotest.(check int) "total is 2" 2 paginated.total;
      Alcotest.(check int) "data length is 2" 2 (List.length paginated.data)

let test_db_article_mark_read () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let person, feed = setup_person_and_feed () in
  let feed_id = Model.Rss_feed.id feed in
  let person_id = Some (Model.Person.id person) in
  let _ =
    Db.Article.upsert
      {
        feed_id;
        person_id;
        title = Some "To Read";
        url = "https://example.com/read";
        published_at = None;
        content = None;
        author = None;
        image_url = None;
      }
  in
  (* Get the article to find its ID *)
  let list_result = Db.Article.list_by_feed ~feed_id ~page:1 ~per_page:10 in
  match list_result with
  | Error err ->
      Alcotest.fail (Format.asprintf "list failed: %a" Caqti_error.pp err)
  | Ok paginated -> (
      let article = List.hd paginated.data in
      let mark_result =
        Db.Article.mark_read ~id:(Model.Article.id article) ~read:true
      in
      match mark_result with
      | Error err ->
          Alcotest.fail
            (Format.asprintf "mark_read failed: %a" Caqti_error.pp err)
      | Ok None -> Alcotest.fail "article not found"
      | Ok (Some updated) ->
          Alcotest.(check bool)
            "read_at is set" true
            (Option.is_some (Model.Article.read_at updated)))

let db_suite =
  [
    Alcotest.test_case "upsert article" `Quick test_db_article_upsert;
    Alcotest.test_case "list articles by feed" `Quick
      test_db_article_list_by_feed;
    Alcotest.test_case "mark article read" `Quick test_db_article_mark_read;
  ]

(* Handler tests are stubbed *)
let handler_suite = []
