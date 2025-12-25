(* Main test runner - imports and runs all test suites *)

let () =
  Alcotest.run "connections-server"
    [
      ("Handlers.Utils", Test_utils.suite);
      ("Model.Person", Test_person.json_suite);
      ("Db.Person", Test_person.db_suite);
      ("Db.Rss_feed", Test_rss_feed.db_suite);
      ("Model.Article", Test_article.json_suite);
      ("Db.Article", Test_article.db_suite);
      ("Feed_fetcher", Test_feed_fetcher.suite);
      ("Opml_parser", Test_opml_parser.suite);
      ("Url_metadata", Test_url_metadata.suite);
      ("E2E", Test_e2e.suite);
    ]
