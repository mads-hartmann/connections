open Tapak
open Response.Syntax

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
  | Error _ -> Response.bad_request "Failed to read request body"
  | Ok body_str ->
      if String.trim body_str = "" then
        Response.bad_request "Request body cannot be empty"
      else
        let sw, env = get_context () in
        let result = Opml_import.preview ~sw ~env body_str in
        (match result with
        | Error msg -> Response.bad_request msg
        | Ok response ->
            Response.json_response
              (Opml_import.preview_response_to_json response))

let confirm request =
  let* req =
    Response.parse_json_body Opml_import.confirm_request_of_json request
    |> Response.or_bad_request
  in
  if List.length req.people = 0 then
    Response.bad_request "No people selected for import"
  else
    let* response = Opml_import.confirm req |> Response.or_internal_error in
    Response.json_response ~status:`Created
      (Opml_import.confirm_response_to_json response)
