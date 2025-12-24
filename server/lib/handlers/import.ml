open Tapak
open Handler_utils.Syntax

(* Store sw and env for OPML import - set by main *)
let sw_ref : Eio.Switch.t option ref = ref None
let env_ref : Eio_unix.Stdenv.base option ref = ref None

let set_context ~sw ~env =
  sw_ref := Some sw;
  env_ref := Some env

let get_context () =
  match (!sw_ref, !env_ref) with
  | Some sw, Some env -> (sw, env)
  | _ -> failwith "Handler context not initialized"

let preview request =
  let body = Request.body request in
  match Body.to_string body with
  | Error _ -> Handler_utils.bad_request "Failed to read request body"
  | Ok body_str -> (
      if String.trim body_str = "" then
        Handler_utils.bad_request "Request body cannot be empty"
      else
        let sw, env = get_context () in
        let result = Opml.Opml_import.preview ~sw ~env body_str in
        match result with
        | Error msg -> Handler_utils.bad_request msg
        | Ok response ->
            Handler_utils.json_response
              (Opml.Opml_import.preview_response_to_json response))

let confirm request =
  let* req =
    Handler_utils.parse_json_body Opml.Opml_import.confirm_request_of_json
      request
    |> Handler_utils.or_bad_request
  in
  if List.length req.people = 0 then
    Handler_utils.bad_request "No people selected for import"
  else
    let* response =
      Opml.Opml_import.confirm req |> Handler_utils.or_internal_error
    in
    Handler_utils.json_response ~status:`Created
      (Opml.Opml_import.confirm_response_to_json response)

let routes () =
  let open Tapak.Router in
  [
    post (s "import" / s "opml" / s "preview") |> request |> into preview;
    post (s "import" / s "opml" / s "confirm") |> request |> into confirm;
  ]
