(* OpenAPI router configuration for Dream *)
module Config = struct
  type app = Dream.handler
  type route = Dream.route
  type handler = Dream.handler

  let json_path = "/openapi.json"
  let doc_path = "/docs"

  let json_route json = Dream.get json_path (fun _ -> Dream.json json)
  let doc_route html = Dream.get doc_path (fun _ -> Dream.html html)

  let get = Dream.get
  let post = Dream.post
  let delete = Dream.delete
  let put = Dream.put
  let options = Dream.options
  let head = Dream.head
  let patch = Dream.patch

  let build_routes = Dream.router
end

module Api = Openapi.Make (Config)

let build () =
  Api.empty
  |> Api.title "Connections Server API"
  |> Api.description "A simple API for managing connections (people)"
  |> Api.version "1.0.0"
  (* List persons *)
  |> Api.get
       ~description:"Returns a paginated list of all persons"
       ~response_body:"PaginatedPersons response with data array, page, per_page, total, total_pages"
       "/persons"
       Handlers.Person.list
  (* Get person by ID *)
  |> Api.get
       ~description:"Returns a single person by their ID"
       ~response_body:"Person object with id and name"
       "/persons/:id"
       Handlers.Person.get
  (* Create person *)
  |> Api.post
       ~description:"Creates a new person with the given name"
       ~request_body:"JSON object with 'name' field"
       ~response_body:"Created Person object with id and name"
       "/persons"
       Handlers.Person.create
  (* Update person *)
  |> Api.put
       ~description:"Updates an existing person's name"
       ~request_body:"JSON object with 'name' field"
       ~response_body:"Updated Person object with id and name"
       "/persons/:id"
       Handlers.Person.update
  (* Delete person *)
  |> Api.delete
       ~description:"Deletes a person by their ID"
       "/persons/:id"
       Handlers.Person.delete
  |> Api.build
