(* Main test runner - imports and runs all test suites *)

let () =
  Alcotest.run "connections-server"
    [
      ("Handlers.Utils", Test_utils.suite);
      ("Model.Connection", Test_connection.json_suite);
      ("Db.Connection", Test_connection.db_suite);
      ("Db.Rss_feed", Test_rss_feed.db_suite);
      ("Model.Uri", Test_uri.json_suite);
      ("Db.Uri", Test_uri.db_suite);
      ("Feed_parser", Test_feed_parser.suite);
      ("Opml_parser", Test_opml_parser.suite);
      ("Metadata", Test_metadata.suite);
      ("E2E", Test_e2e.suite);
    ]
