open Tapak
open Handler_utils.Syntax
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

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

let list_by_feed (pagination : Pagination.Pagination.t) feed_id =
  let* _ = Service.Rss_feed.get ~id:feed_id |> Handler_utils.or_feed_error in
  let* paginated =
    Service.Uri.list_by_feed ~feed_id ~page:pagination.page
      ~per_page:pagination.per_page
    |> Handler_utils.or_uri_error
  in
  Handler_utils.json_response (Model.Uri_entry.paginated_to_json paginated)

let list_by_connection request (pagination : Pagination.Pagination.t) connection_id =
  let* _ = Service.Connection.get ~id:connection_id |> Handler_utils.or_connection_error in
  let unread_only = Handler_utils.query "unread" request = Some "true" in
  let* paginated =
    Service.Uri.list_by_connection ~connection_id ~page:pagination.page
      ~per_page:pagination.per_page ~unread_only
    |> Handler_utils.or_uri_error
  in
  Handler_utils.json_response (Model.Uri_entry.paginated_to_json paginated)

let list_all request (pagination : Pagination.Pagination.t) =
  let unread_only = Handler_utils.query "unread" request = Some "true" in
  let read_later_only = Handler_utils.query "read_later" request = Some "true" in
  let orphan_only = Handler_utils.query "orphan" request = Some "true" in
  let tag = Handler_utils.query "tag" request in
  let query = Handler_utils.query "query" request in
  let* paginated =
    Service.Uri.list_all ~page:pagination.page ~per_page:pagination.per_page
      ~unread_only ~read_later_only ~tag ~orphan_only ?query ()
    |> Handler_utils.or_uri_error
  in
  Handler_utils.json_response (Model.Uri_entry.paginated_to_json paginated)

let get_uri _request id =
  let* uri = Service.Uri.get ~id |> Handler_utils.or_uri_error in
  Handler_utils.json_response (Model.Uri_entry.to_json uri)

type create_request = {
  url : string;
  connection_id : int option; [@yojson.option]
  kind : string option; [@yojson.option]
  title : string option; [@yojson.option]
}
[@@deriving yojson]

let create request =
  let* { url; connection_id; kind; title } =
    Handler_utils.parse_json_body create_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  let* valid_url =
    Handler_utils.validate_url url |> Handler_utils.or_bad_request
  in
  let uri_kind =
    match kind with
    | Some k -> (
        match Model.Uri_kind.of_string k with
        | Some k -> k
        | None -> Model.Uri_kind.Unknown)
    | None -> Model.Uri_kind.Unknown
  in
  let* uri =
    Service.Uri.create ~connection_id ~kind:uri_kind ~url:valid_url ~title
    |> Handler_utils.or_uri_error
  in
  Handler_utils.json_response ~status:`Created (Model.Uri_entry.to_json uri)

type update_request = {
  connection_id : int option; [@yojson.option]
  kind : string option; [@yojson.option]
  title : string option; [@yojson.option]
}
[@@deriving yojson]

let update request id =
  let* { connection_id; kind; title } =
    Handler_utils.parse_json_body update_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  let* current_uri = Service.Uri.get ~id |> Handler_utils.or_uri_error in
  let uri_kind =
    match kind with
    | Some k -> (
        match Model.Uri_kind.of_string k with
        | Some k -> k
        | None -> Model.Uri_entry.kind current_uri)
    | None -> Model.Uri_entry.kind current_uri
  in
  let new_connection_id =
    match connection_id with
    | Some _ -> connection_id
    | None -> Model.Uri_entry.connection_id current_uri
  in
  let new_title =
    match title with
    | Some _ -> title
    | None -> Model.Uri_entry.title current_uri
  in
  let* uri =
    Service.Uri.update ~id ~connection_id:new_connection_id ~kind:uri_kind ~title:new_title
    |> Handler_utils.or_uri_error
  in
  Handler_utils.json_response (Model.Uri_entry.to_json uri)

type mark_read_request = { read : bool } [@@deriving yojson]

let mark_read request id =
  let* { read } =
    Handler_utils.parse_json_body mark_read_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  let* uri =
    Service.Uri.mark_read ~id ~read |> Handler_utils.or_uri_error
  in
  Handler_utils.json_response (Model.Uri_entry.to_json uri)

type mark_read_later_request = { read_later : bool } [@@deriving yojson]

let mark_read_later request id =
  let* { read_later } =
    Handler_utils.parse_json_body mark_read_later_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  let* uri =
    Service.Uri.mark_read_later ~id ~read_later
    |> Handler_utils.or_uri_error
  in
  Handler_utils.json_response (Model.Uri_entry.to_json uri)

let mark_all_read _request feed_id =
  let* _ = Service.Rss_feed.get ~id:feed_id |> Handler_utils.or_feed_error in
  let* count =
    Service.Uri.mark_all_read ~feed_id |> Handler_utils.or_uri_error
  in
  Handler_utils.json_response (`Assoc [ ("marked_read", `Int count) ])

let mark_all_read_global _request =
  let* count =
    Service.Uri.mark_all_read_global () |> Handler_utils.or_uri_error
  in
  Handler_utils.json_response (`Assoc [ ("marked_read", `Int count) ])

let delete_uri _request id =
  let* () = Service.Uri.delete ~id |> Handler_utils.or_uri_error in
  Response.of_string ~body:"" `No_content

let refresh_metadata _request id =
  let* uri = Service.Uri.get ~id |> Handler_utils.or_uri_error in
  let sw, env = get_context () in
  let* updated =
    Cron.Uri_metadata_sync.fetch_for_uri ~sw ~env uri
    |> Handler_utils.or_db_error
  in
  let* result =
    updated |> Handler_utils.or_not_found "URI not found after update"
  in
  Handler_utils.json_response (Model.Uri_entry.to_json result)

let get_content _request id =
  let sw, env = get_context () in
  let* markdown =
    Service.Uri_content.get ~sw ~env ~uri_id:id
    |> Handler_utils.or_uri_content_error
  in
  Handler_utils.json_response (`Assoc [ ("markdown", `String markdown) ])

let routes () =
  let open Tapak.Router in
  [
    get (s "feeds" / int / s "uris")
    |> extract Pagination.Pagination.pagination_extractor
    |> into list_by_feed;
    post (s "feeds" / int / s "uris" / s "mark-all-read")
    |> request |> into mark_all_read;
    get (s "connections" / int / s "uris")
    |> extract Pagination.Pagination.pagination_extractor
    |> request |> into list_by_connection;
    get (s "uris")
    |> extract Pagination.Pagination.pagination_extractor
    |> request |> into list_all;
    post (s "uris") |> request |> into create;
    post (s "uris" / s "mark-all-read")
    |> request |> into mark_all_read_global;
    get (s "uris" / int) |> request |> into get_uri;
    put (s "uris" / int) |> request |> into update;
    post (s "uris" / int / s "read") |> request |> into mark_read;
    post (s "uris" / int / s "read-later") |> request |> into mark_read_later;
    post (s "uris" / int / s "refresh-metadata")
    |> request |> into refresh_metadata;
    get (s "uris" / int / s "content") |> request |> into get_content;
    delete (s "uris" / int) |> request |> into delete_uri;
  ]
