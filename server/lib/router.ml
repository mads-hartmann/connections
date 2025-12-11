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
      Dream.post "/persons/:person_id/feeds" Handlers.RssFeed.create;
      Dream.get "/persons/:person_id/feeds" Handlers.RssFeed.list_by_person;
      (* RSS Feed routes - top-level for direct access *)
      Dream.get "/feeds/:id" Handlers.RssFeed.get;
      Dream.put "/feeds/:id" Handlers.RssFeed.update;
      Dream.delete "/feeds/:id" Handlers.RssFeed.delete;
    ]
