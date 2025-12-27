open Tapak
open Handler_utils.Syntax
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type create_request = { field_type_id : int; value : string } [@@deriving yojson]
type update_request = { value : string } [@@deriving yojson]

let create request person_id =
  let* { field_type_id; value } =
    Handler_utils.parse_json_body create_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  if String.trim value = "" then Handler_utils.bad_request "Value cannot be empty"
  else
    let* metadata =
      Service.Person_metadata.create ~person_id ~field_type_id ~value
      |> Handler_utils.or_person_metadata_error
    in
    Handler_utils.json_response ~status:`Created
      (Model.Person_metadata.to_json metadata)

let update request person_id metadata_id =
  let* { value } =
    Handler_utils.parse_json_body update_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  if String.trim value = "" then Handler_utils.bad_request "Value cannot be empty"
  else
    let* metadata =
      Service.Person_metadata.update ~id:metadata_id ~person_id ~value
      |> Handler_utils.or_person_metadata_error
    in
    Handler_utils.json_response (Model.Person_metadata.to_json metadata)

let delete_metadata _request person_id metadata_id =
  let* () =
    Service.Person_metadata.delete ~id:metadata_id ~person_id
    |> Handler_utils.or_person_metadata_error
  in
  Response.of_string ~body:"" `No_content

let routes () =
  let open Tapak.Router in
  [
    post (s "persons" / int / s "metadata") |> request |> into create;
    put (s "persons" / int / s "metadata" / int) |> request |> into update;
    delete (s "persons" / int / s "metadata" / int)
    |> request |> into delete_metadata;
  ]
