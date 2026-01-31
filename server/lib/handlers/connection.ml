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

let list request (pagination : Pagination.Pagination.t) =
  let query = Handler_utils.query "query" request in
  let* paginated =
    Service.Connection.list_with_counts ~page:pagination.page
      ~per_page:pagination.per_page ?query ()
    |> Handler_utils.or_connection_error
  in
  Handler_utils.json_response
    (Model.Connection.paginated_with_counts_to_json paginated)

let get_connection _request id =
  let* connection = Service.Connection.get ~id |> Handler_utils.or_connection_error in
  Handler_utils.json_response (Model.Connection.to_json connection)

type create_request = { name : string; url : string option [@yojson.option] }
[@@deriving yojson]

let create request =
  let* { name; url } =
    Handler_utils.parse_json_body create_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  if String.trim name = "" then Handler_utils.bad_request "Name cannot be empty"
  else
    let* connection =
      Service.Connection.create ~name () |> Handler_utils.or_connection_error
    in
    let () =
      match url with
      | Some url when String.trim url <> "" ->
          let website_field_type_id = Model.Metadata_field_type.(id Website) in
          let _ =
            Service.Connection_metadata.create ~connection_id:(Model.Connection.id connection)
              ~field_type_id:website_field_type_id ~value:url
          in
          ()
      | _ -> ()
    in
    Handler_utils.json_response ~status:`Created (Model.Connection.to_json connection)

type update_request = {
  name : string;
  photo : string option; [@yojson.option]
}
[@@deriving yojson]

let update request id =
  let* { name; photo } =
    Handler_utils.parse_json_body update_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  if String.trim name = "" then Handler_utils.bad_request "Name cannot be empty"
  else
    let* connection =
      Service.Connection.update ~id ~name ~photo |> Handler_utils.or_connection_error
    in
    Handler_utils.json_response (Model.Connection.to_json connection)

let delete_connection _request id =
  let* () = Service.Connection.delete ~id |> Handler_utils.or_connection_error in
  Response.of_string ~body:"" `No_content

(* Find the Website metadata field for a connection *)
let find_website_url (connection : Model.Connection.t) =
  List.find_opt
    (fun m ->
      Model.Metadata_field_type.equal
        (Model.Connection_metadata.field_type m)
        Model.Metadata_field_type.Website)
    (Model.Connection.metadata connection)
  |> Option.map Model.Connection_metadata.value

(* Refresh metadata preview - fetches metadata from connection's website and returns proposed changes *)
let refresh_metadata_preview _request id =
  let* connection = Service.Connection.get ~id |> Handler_utils.or_connection_error in
  let* website_url =
    find_website_url connection
    |> Handler_utils.or_bad_request_opt
         "Connection has no Website metadata field. Add a website URL first."
  in
  let* valid_url =
    Handler_utils.validate_url website_url |> Handler_utils.or_bad_request
  in
  let sw, env = get_context () in
  let* contact =
    Metadata.Contact.fetch ~sw ~env valid_url |> Handler_utils.or_bad_request
  in
  (* Build the preview response showing current vs proposed values *)
  let current_metadata = Model.Connection.metadata connection in
  let opt_field name = function
    | Some v -> [ (name, `String v) ]
    | None -> []
  in
  let feed_to_json (f : Metadata.Contact.Feed.t) =
    `Assoc
      ([
         ("url", `String f.url);
         ( "format",
           `String
             (match f.format with
             | Metadata.Contact.Feed.Rss -> "rss"
             | Atom -> "atom"
             | Json_feed -> "json_feed") );
       ]
      @ opt_field "title" f.title)
  in
  let profile_to_json (p : Metadata.Contact.Classified_profile.t) =
    `Assoc
      [
        ("url", `String p.url);
        ("field_type", Model.Metadata_field_type.to_json_with_id p.field_type);
      ]
  in
  let current_metadata_json =
    List.map Model.Connection_metadata.to_json current_metadata
  in
  let response =
    `Assoc
      ([
         ("connection_id", `Int id);
         ("source_url", `String valid_url);
       ]
      @ opt_field "proposed_name" contact.name
      @ opt_field "proposed_photo" contact.photo
      @ [
          ("proposed_feeds", `List (List.map feed_to_json contact.feeds));
          ( "proposed_profiles",
            `List (List.map profile_to_json contact.social_profiles) );
          ("current_name", `String (Model.Connection.name connection));
        ]
      @ opt_field "current_photo" (Model.Connection.photo connection)
      @ [ ("current_metadata", `List current_metadata_json) ])
  in
  Handler_utils.json_response response

let routes () =
  let open Tapak.Router in
  [
    get (s "connections")
    |> extract Pagination.Pagination.pagination_extractor
    |> request |> into list;
    get (s "connections" / int) |> request |> into get_connection;
    get (s "connections" / int / s "refresh-metadata")
    |> request |> into refresh_metadata_preview;
    post (s "connections") |> request |> into create;
    put (s "connections" / int) |> request |> into update;
    delete (s "connections" / int) |> request |> into delete_connection;
  ]
