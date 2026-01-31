open Tapak
open Handler_utils.Syntax
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

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

type create_request = {
  connection_id : int;
  url : string;
  title : string option; [@yojson.option]
}
[@@deriving yojson]

let create request connection_id =
  let* { connection_id = body_connection_id; url; title } =
    Handler_utils.parse_json_body create_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  if body_connection_id <> connection_id then
    Handler_utils.bad_request
      "connection_id in URL does not match connection_id in body"
  else
    let* valid_url =
      Handler_utils.validate_url url |> Handler_utils.or_bad_request
    in
    let* feed =
      Service.Rss_feed.create ~connection_id ~url:valid_url ~title
      |> Handler_utils.or_feed_error
    in
    let sw, env = get_context () in
    Eio.Fiber.fork ~sw (fun () -> Cron.Feed_sync.process_feed ~sw ~env feed);
    Handler_utils.json_response ~status:`Created (Model.Rss_feed.to_json feed)

let list_by_connection (pagination : Pagination.Pagination.t) connection_id =
  let* _ = Service.Connection.get ~id:connection_id |> Handler_utils.or_connection_error in
  let* paginated =
    Service.Rss_feed.list_by_connection ~connection_id ~page:pagination.page
      ~per_page:pagination.per_page
    |> Handler_utils.or_feed_error
  in
  Handler_utils.json_response (Model.Rss_feed.paginated_to_json paginated)

let get_feed _request id =
  let* feed = Service.Rss_feed.get ~id |> Handler_utils.or_feed_error in
  Handler_utils.json_response (Model.Rss_feed.to_json feed)

type update_request = {
  url : string option; [@yojson.option]
  title : string option; [@yojson.option]
}
[@@deriving yojson]

let update request id =
  let* { url; title } =
    Handler_utils.parse_json_body update_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  let* validated_url =
    (match url with
      | None -> Ok None
      | Some u -> Result.map Option.some (Handler_utils.validate_url u))
    |> Handler_utils.or_bad_request
  in
  let* feed =
    Service.Rss_feed.update ~id ~url:validated_url ~title
    |> Handler_utils.or_feed_error
  in
  Handler_utils.json_response (Model.Rss_feed.to_json feed)

let delete_feed _request id =
  let* () = Service.Rss_feed.delete ~id |> Handler_utils.or_feed_error in
  Response.of_string ~body:"" `No_content

let refresh _request id =
  let* feed = Service.Rss_feed.get ~id |> Handler_utils.or_feed_error in
  let sw, env = get_context () in
  Cron.Feed_sync.process_feed ~sw ~env feed;
  Handler_utils.json_response (`Assoc [ ("message", `String "Feed refreshed") ])

let list_all request (pagination : Pagination.Pagination.t) =
  let query = Handler_utils.query "query" request in
  let* paginated =
    Service.Rss_feed.list_all_paginated ~page:pagination.page
      ~per_page:pagination.per_page ?query ()
    |> Handler_utils.or_feed_error
  in
  Handler_utils.json_response (Model.Rss_feed.paginated_to_json paginated)

let routes () =
  let open Tapak.Router in
  [
    post (s "connections" / int / s "feeds") |> request |> into create;
    get (s "connections" / int / s "feeds")
    |> extract Pagination.Pagination.pagination_extractor
    |> into list_by_connection;
    get (s "feeds")
    |> extract Pagination.Pagination.pagination_extractor
    |> request |> into list_all;
    get (s "feeds" / int) |> request |> into get_feed;
    put (s "feeds" / int) |> request |> into update;
    delete (s "feeds" / int) |> request |> into delete_feed;
    post (s "feeds" / int / s "refresh") |> request |> into refresh;
  ]
