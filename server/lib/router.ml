let build () =
  Dream.router
    [
      (* Person routes *)
      Dream.get "/persons" Handlers.Person.list;
      Dream.get "/persons/:id" Handlers.Person.get;
      Dream.post "/persons" Handlers.Person.create;
      Dream.put "/persons/:id" Handlers.Person.update;
      Dream.delete "/persons/:id" Handlers.Person.delete;
      (* RSS Feed routes - nested under persons *)
      Dream.post "/persons/:person_id/feeds" Handlers.Rss_feed.create;
      Dream.get "/persons/:person_id/feeds" Handlers.Rss_feed.list_by_person;
      (* Person-Category routes *)
      Dream.get "/persons/:person_id/categories"
        Handlers.Category.list_by_person;
      Dream.post "/persons/:person_id/categories/:category_id"
        Handlers.Category.add_to_person;
      Dream.delete "/persons/:person_id/categories/:category_id"
        Handlers.Category.remove_from_person;
      (* RSS Feed routes - top-level for direct access *)
      Dream.get "/feeds" Handlers.Rss_feed.list_all;
      Dream.get "/feeds/:id" Handlers.Rss_feed.get;
      Dream.put "/feeds/:id" Handlers.Rss_feed.update;
      Dream.delete "/feeds/:id" Handlers.Rss_feed.delete;
      Dream.post "/feeds/:id/refresh" Handlers.Rss_feed.refresh;
      (* Article routes - nested under feeds *)
      Dream.get "/feeds/:feed_id/articles" Handlers.Article.list_by_feed;
      Dream.post "/feeds/:feed_id/articles/mark-all-read"
        Handlers.Article.mark_all_read;
      (* Article routes - top-level *)
      Dream.get "/articles" Handlers.Article.list_all;
      Dream.get "/articles/:id" Handlers.Article.get;
      Dream.post "/articles/:id/read" Handlers.Article.mark_read;
      Dream.delete "/articles/:id" Handlers.Article.delete;
      (* Category routes *)
      Dream.get "/categories" Handlers.Category.list;
      Dream.get "/categories/:id" Handlers.Category.get;
      Dream.post "/categories" Handlers.Category.create;
      Dream.delete "/categories/:id" Handlers.Category.delete;
      (* Import routes *)
      Dream.post "/import/opml/preview" Handlers.Import.preview;
      Dream.post "/import/opml/confirm" Handlers.Import.confirm;
    ]
