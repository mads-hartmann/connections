open Tapak

let not_found _req =
  let headers = Piaf.Headers.of_list [ ("content-type", "application/json") ] in
  Response.of_string ~headers ~body:"{\"error\": \"Not found\"}" `Not_found

let build () =
  let open Router in
  App.routes ~not_found
    [
      (* Person routes *)
      get (s "persons") |> request |> into Handlers.Person.list;
      get (s "persons" / int64) |> request |> into Handlers.Person.get;
      post (s "persons") |> request |> into Handlers.Person.create;
      put (s "persons" / int64) |> request |> into Handlers.Person.update;
      delete (s "persons" / int64) |> request |> into Handlers.Person.delete;
      (* RSS Feed routes - nested under persons *)
      post (s "persons" / int64 / s "feeds")
      |> request
      |> into Handlers.Rss_feed.create;
      get (s "persons" / int64 / s "feeds")
      |> request
      |> into Handlers.Rss_feed.list_by_person;
      (* Person-Category routes *)
      get (s "persons" / int64 / s "categories")
      |> request
      |> into Handlers.Category.list_by_person;
      post (s "persons" / int64 / s "categories" / int64)
      |> request
      |> into Handlers.Category.add_to_person;
      delete (s "persons" / int64 / s "categories" / int64)
      |> request
      |> into Handlers.Category.remove_from_person;
      (* RSS Feed routes - top-level for direct access *)
      get (s "feeds") |> request |> into Handlers.Rss_feed.list_all;
      get (s "feeds" / int64) |> request |> into Handlers.Rss_feed.get;
      put (s "feeds" / int64) |> request |> into Handlers.Rss_feed.update;
      delete (s "feeds" / int64) |> request |> into Handlers.Rss_feed.delete;
      post (s "feeds" / int64 / s "refresh")
      |> request
      |> into Handlers.Rss_feed.refresh;
      (* Article routes - nested under feeds *)
      get (s "feeds" / int64 / s "articles")
      |> request
      |> into Handlers.Article.list_by_feed;
      post (s "feeds" / int64 / s "articles" / s "mark-all-read")
      |> request
      |> into Handlers.Article.mark_all_read;
      (* Article routes - top-level *)
      get (s "articles") |> request |> into Handlers.Article.list_all;
      get (s "articles" / int64) |> request |> into Handlers.Article.get;
      post (s "articles" / int64 / s "read")
      |> request
      |> into Handlers.Article.mark_read;
      delete (s "articles" / int64) |> request |> into Handlers.Article.delete;
      (* Category routes *)
      get (s "categories") |> request |> into Handlers.Category.list;
      get (s "categories" / int64) |> request |> into Handlers.Category.get;
      post (s "categories") |> request |> into Handlers.Category.create;
      delete (s "categories" / int64)
      |> request
      |> into Handlers.Category.delete;
      (* Import routes *)
      post (s "import" / s "opml" / s "preview")
      |> request
      |> into Handlers.Import.preview;
      post (s "import" / s "opml" / s "confirm")
      |> request
      |> into Handlers.Import.confirm;
    ]
    ()
