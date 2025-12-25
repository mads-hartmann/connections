open Tapak
open Handler_utils.Syntax
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

let list (pagination : Pagination.Pagination.t) =
  let* response =
    Service.Tag.list ~page:pagination.page ~per_page:pagination.per_page ()
    |> Handler_utils.or_tag_error
  in
  Handler_utils.json_response (Model.Tag.paginated_to_json response)

let get_tag _request id =
  let* tag = Service.Tag.get ~id |> Handler_utils.or_tag_error in
  Handler_utils.json_response (Model.Tag.to_json tag)

type create_request = { name : string } [@@deriving yojson]

let create request =
  let* { name } =
    Handler_utils.parse_json_body create_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  if String.trim name = "" then Handler_utils.bad_request "Name cannot be empty"
  else
    let* tag = Service.Tag.create ~name |> Handler_utils.or_tag_error in
    Handler_utils.json_response ~status:`Created (Model.Tag.to_json tag)

let delete_tag _request id =
  let* () = Service.Tag.delete ~id |> Handler_utils.or_tag_error in
  Response.of_string ~body:"" `No_content

let add_to_person _request person_id tag_id =
  let* () =
    Service.Tag.add_to_person ~person_id ~tag_id |> Handler_utils.or_tag_error
  in
  Response.of_string ~body:"" `No_content

let remove_from_person _request person_id tag_id =
  let* () =
    Service.Tag.remove_from_person ~person_id ~tag_id
    |> Handler_utils.or_tag_error
  in
  Response.of_string ~body:"" `No_content

let list_by_person _request person_id =
  let* tags =
    Service.Tag.get_by_person ~person_id |> Handler_utils.or_tag_error
  in
  Handler_utils.json_response (Model.Tag.list_to_json tags)

let routes () =
  let open Tapak.Router in
  [
    get (s "tags") |> guard Pagination.Pagination.pagination_guard |> into list;
    get (s "tags" / int) |> request |> into get_tag;
    post (s "tags") |> request |> into create;
    delete (s "tags" / int) |> request |> into delete_tag;
    get (s "persons" / int / s "tags") |> request |> into list_by_person;
    post (s "persons" / int / s "tags" / int) |> request |> into add_to_person;
    delete (s "persons" / int / s "tags" / int)
    |> request |> into remove_from_person;
  ]
