open Tapak
open Response.Syntax

(* Store sw and env for feed processing - set by main *)
let sw_ref : Eio.Switch.t option ref = ref None
let env_ref : Eio_unix.Stdenv.base option ref = ref None

let set_context ~sw ~env =
  sw_ref := Some sw;
  env_ref := Some env

let get_context () =
  match (!sw_ref, !env_ref) with
  | Some sw, Some env -> (sw, env)
  | _ -> failwith "Handler context not initialized"

let create person_id request =
  let* { person_id = body_person_id; url; title } =
    Response.parse_json_body Model.Rss_feed.create_request_of_yojson request
    |> Response.or_bad_request
  in
  let person_id = Int64.to_int person_id in
  if body_person_id <> person_id then
    Response.bad_request "person_id in URL does not match person_id in body"
  else
    let* valid_url = Response.validate_url url |> Response.or_bad_request in
    let* feed =
      Db.Rss_feed.create ~person_id ~url:valid_url ~title
      |> Response.or_internal_error
    in
    Response.json_response ~status:`Created (Model.Rss_feed.to_json feed)

let list_by_person person_id request =
  let person_id = Int64.to_int person_id in
  let* person_result =
    Db.Person.get ~id:person_id |> Response.or_internal_error
  in
  let* _ = person_result |> Response.or_not_found "Person not found" in
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let* paginated =
    Db.Rss_feed.list_by_person ~person_id ~page ~per_page
    |> Response.or_internal_error
  in
  Response.json_response (Model.Rss_feed.paginated_to_json paginated)

let get id _request =
  let* result =
    Db.Rss_feed.get ~id:(Int64.to_int id) |> Response.or_internal_error
  in
  let* feed = result |> Response.or_not_found "Feed not found" in
  Response.json_response (Model.Rss_feed.to_json feed)

let update id request =
  let* { url; title } =
    Response.parse_json_body Model.Rss_feed.update_request_of_yojson request
    |> Response.or_bad_request
  in
  let* validated_url =
    (match url with
    | None -> Ok None
    | Some u -> Result.map Option.some (Response.validate_url u))
    |> Response.or_bad_request
  in
  let* result =
    Db.Rss_feed.update ~id:(Int64.to_int id) ~url:validated_url ~title
    |> Response.or_internal_error
  in
  let* feed = result |> Response.or_not_found "Feed not found" in
  Response.json_response (Model.Rss_feed.to_json feed)

let delete id _request =
  let* result =
    Db.Rss_feed.delete ~id:(Int64.to_int id) |> Response.or_internal_error
  in
  if result then Response.of_string ~body:"" `No_content
  else Response.not_found "Feed not found"

let refresh id _request =
  let* result =
    Db.Rss_feed.get ~id:(Int64.to_int id) |> Response.or_internal_error
  in
  let* feed = result |> Response.or_not_found "Feed not found" in
  let sw, env = get_context () in
  Feed_fetcher.process_feed ~sw ~env feed;
  Response.json_response (`Assoc [ ("message", `String "Feed refreshed") ])

let list_all request =
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page =
    min 100 (max 1 (Response.parse_query_int "per_page" 10 request))
  in
  let* paginated =
    Db.Rss_feed.list_all_paginated ~page ~per_page |> Response.or_internal_error
  in
  Response.json_response (Model.Rss_feed.paginated_to_json paginated)
