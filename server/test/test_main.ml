(* Main test runner - imports and runs all test suites *)

let () =
  Lwt_main.run
    (Alcotest_lwt.run "connections-server"
       [
         ("Handlers.Utils", Test_utils.suite);
         ("Model.Person", Test_person.json_suite);
         ("Db.Person", Test_person.db_suite);
         ("Handlers.Person", Test_person.handler_suite);
         ("Db.Rss_feed", Test_rss_feed.db_suite);
         ("Model.Article", Test_article.json_suite);
         ("Db.Article", Test_article.db_suite);
         ("Handlers.Article", Test_article.handler_suite);
         ("Feed_fetcher", Test_feed_fetcher.suite);
         ("Opml_parser", Test_opml_parser.suite);
       ])
