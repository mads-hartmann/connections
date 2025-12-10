let build () =
  Dream.router
    [
      Dream.get "/persons" Handlers.Person.list;
      Dream.get "/persons/:id" Handlers.Person.get;
      Dream.post "/persons" Handlers.Person.create;
      Dream.put "/persons/:id" Handlers.Person.update;
      Dream.delete "/persons/:id" Handlers.Person.delete;
    ]
