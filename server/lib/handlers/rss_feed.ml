open Tapak
open Handler_utils.Syntax

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

let create request person_id =
  let* { person_id = body_person_id; url; title } =
    Handler_utils.parse_json_body Model.Rss_feed.create_request_of_yojson
      request
    |> Handler_utils.or_bad_request
  in
  if body_person_id <> person_id then
    Handler_utils.bad_request
      "person_id in URL does not match person_id in body"
  else
    let* valid_url =
      Handler_utils.validate_url url |> Handler_utils.or_bad_request
    in
    let* feed =
      Db.Rss_feed.create ~person_id ~url:valid_url ~title
      |> Handler_utils.or_internal_error
    in
    Handler_utils.json_response ~status:`Created (Model.Rss_feed.to_json feed)

let list_by_person (pagination : Pagination.pagination) person_id =
  let* person_result =
    Db.Person.get ~id:person_id |> Handler_utils.or_internal_error
  in
  let* _ = person_result |> Handler_utils.or_not_found "Person not found" in
  let* paginated =
    Db.Rss_feed.list_by_person ~person_id ~page:pagination.Pagination.page
      ~per_page:pagination.Pagination.per_page
    |> Handler_utils.or_internal_error
  in
  Handler_utils.json_response (Model.Rss_feed.paginated_to_json paginated)

let get_feed _request id =
  let* result = Db.Rss_feed.get ~id |> Handler_utils.or_internal_error in
  let* feed = result |> Handler_utils.or_not_found "Feed not found" in
  Handler_utils.json_response (Model.Rss_feed.to_json feed)

let update request id =
  let* { url; title } =
    Handler_utils.parse_json_body Model.Rss_feed.update_request_of_yojson
      request
    |> Handler_utils.or_bad_request
  in
  let* validated_url =
    (match url with
      | None -> Ok None
      | Some u -> Result.map Option.some (Handler_utils.validate_url u))
    |> Handler_utils.or_bad_request
  in
  let* result =
    Db.Rss_feed.update ~id ~url:validated_url ~title
    |> Handler_utils.or_internal_error
  in
  let* feed = result |> Handler_utils.or_not_found "Feed not found" in
  Handler_utils.json_response (Model.Rss_feed.to_json feed)

let delete_feed _request id =
  let* result = Db.Rss_feed.delete ~id |> Handler_utils.or_internal_error in
  if result then Response.of_string ~body:"" `No_content
  else Handler_utils.not_found "Feed not found"

let refresh _request id =
  let* result = Db.Rss_feed.get ~id |> Handler_utils.or_internal_error in
  let* feed = result |> Handler_utils.or_not_found "Feed not found" in
  let sw, env = get_context () in
  Feed_fetcher.process_feed ~sw ~env feed;
  Handler_utils.json_response (`Assoc [ ("message", `String "Feed refreshed") ])

let list_all (pagination : Pagination.pagination) =
  let* paginated =
    Db.Rss_feed.list_all_paginated ~page:pagination.Pagination.page
      ~per_page:pagination.Pagination.per_page
    |> Handler_utils.or_internal_error
  in
  Handler_utils.json_response (Model.Rss_feed.paginated_to_json paginated)

let routes () =
  let open Tapak.Router in
  [
    post (s "persons" / int / s "feeds") |> request |> into create;
    get (s "persons" / int / s "feeds")
    |> guard Pagination.pagination_guard
    |> into list_by_person;
    get (s "feeds") |> guard Pagination.pagination_guard |> into list_all;
    get (s "feeds" / int) |> request |> into get_feed;
    put (s "feeds" / int) |> request |> into update;
    delete (s "feeds" / int) |> request |> into delete_feed;
    post (s "feeds" / int / s "refresh") |> request |> into refresh;
  ]
