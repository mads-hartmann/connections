open Handler_utils.Syntax

let set_context = Handler_context.set_context
let get_context = Handler_context.get_context

let extract req =
  let* url =
    Handler_utils.query "url" req
    |> Handler_utils.or_not_found "Missing 'url' query parameter"
  in
  let* valid_url =
    Handler_utils.validate_url url |> Handler_utils.or_bad_request
  in
  let sw, env = get_context () in
  let* result =
    Url_metadata.fetch_full ~sw ~env valid_url |> Handler_utils.or_bad_request
  in
  Handler_utils.json_response (Url_metadata.full_response_to_json result)

let routes () : Tapak.Router.route list =
  [ Tapak.Router.into extract (Tapak.Router.request (Tapak.Router.get (Tapak.Router.s "url-metadata"))) ]
