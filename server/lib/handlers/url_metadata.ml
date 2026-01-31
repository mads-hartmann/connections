open Handler_utils.Syntax

(* Store sw and env for HTTP requests - set by main *)
let sw_ref : Eio.Switch.t option ref = ref None
let env_ref : Eio_unix.Stdenv.base option ref = ref None

let set_context ~sw ~env =
  sw_ref := Some sw;
  env_ref := Some env

let get_context () =
  match (!sw_ref, !env_ref) with
  | Some sw, Some env -> (sw, env)
  | _ -> failwith "Handler context not initialized"

(* Connection metadata - person/site information *)
let connection_handler request =
  let* url =
    Handler_utils.query "url" request
    |> Handler_utils.or_not_found "Missing 'url' query parameter"
  in
  let* valid_url =
    Handler_utils.validate_url url |> Handler_utils.or_bad_request
  in
  let sw, env = get_context () in
  let* result =
    Metadata.Contact.fetch ~sw ~env valid_url |> Handler_utils.or_bad_request
  in
  Handler_utils.json_response (Metadata.Contact.to_json result)

(* URI metadata - content information *)
let uri_handler request =
  let* url =
    Handler_utils.query "url" request
    |> Handler_utils.or_not_found "Missing 'url' query parameter"
  in
  let* valid_url =
    Handler_utils.validate_url url |> Handler_utils.or_bad_request
  in
  let sw, env = get_context () in
  let* result =
    Metadata.Article.fetch ~sw ~env valid_url |> Handler_utils.or_bad_request
  in
  Handler_utils.json_response (Metadata.Article.to_json result)

let routes () =
  let open Tapak.Router in
  [
    get (s "discovery" / s "connection-metadata") |> request |> into connection_handler;
    get (s "discovery" / s "uri-metadata") |> request |> into uri_handler;
  ]
