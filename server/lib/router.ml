open Tapak

let not_found _req =
  let headers = Piaf.Headers.of_list [ ("content-type", "application/json") ] in
  Response.of_string ~headers ~body:"{\"error\": \"Not found\"}" `Not_found

let health_check _req =
  let headers = Piaf.Headers.of_list [ ("content-type", "application/json") ] in
  Response.of_string ~headers ~body:"{\"status\": \"ok\"}" `OK

let health_routes () =
  let open Tapak.Router in
  [ get (s "health") |> request |> into health_check ]

let build () =
  App.routes ~not_found
    (List.concat
       [
         health_routes ();
         Handlers.Person.routes ();
         Handlers.Rss_feed.routes ();
         Handlers.Article.routes ();
         Handlers.Category.routes ();
         Handlers.Import.routes ();
         Handlers.Metadata.routes ();
       ])
    ()
