open Tapak
open Handler_utils.Syntax
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type create_request = { field_type_id : int; value : string }
[@@deriving yojson]

type update_request = { value : string } [@@deriving yojson]

let create request connection_id =
  let* { field_type_id; value } =
    Handler_utils.parse_json_body create_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  let value = String.trim value in
  if value = "" then Handler_utils.bad_request "Value cannot be empty"
  else
    let* metadata =
      Service.Connection_metadata.create ~connection_id ~field_type_id ~value
      |> Handler_utils.or_connection_metadata_error
    in
    Handler_utils.json_response (Model.Connection_metadata.to_json metadata)

let update request connection_id metadata_id =
  let* { value } =
    Handler_utils.parse_json_body update_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  if String.trim value = "" then
    Handler_utils.bad_request "Value cannot be empty"
  else
    let* metadata =
      Service.Connection_metadata.update ~id:metadata_id ~connection_id ~value
      |> Handler_utils.or_connection_metadata_error
    in
    Handler_utils.json_response (Model.Connection_metadata.to_json metadata)

let delete_metadata _request connection_id metadata_id =
  let* () =
    Service.Connection_metadata.delete ~id:metadata_id ~connection_id
    |> Handler_utils.or_connection_metadata_error
  in
  Response.of_string ~body:"" `No_content

let routes () =
  let open Tapak.Router in
  [
    post (s "connections" / int / s "metadata") |> request |> into create;
    put (s "connections" / int / s "metadata" / int) |> request |> into update;
    delete (s "connections" / int / s "metadata" / int)
    |> request |> into delete_metadata;
  ]
