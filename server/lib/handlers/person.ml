open Tapak
open Handler_utils.Syntax
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

let list request (pagination : Pagination.Pagination.t) =
  let query = Handler_utils.query "query" request in
  let* paginated =
    Service.Person.list_with_counts ~page:pagination.page
      ~per_page:pagination.per_page ?query ()
    |> Handler_utils.or_person_error
  in
  Handler_utils.json_response
    (Model.Person.paginated_with_counts_to_json paginated)

let get_person _request id =
  let* person = Service.Person.get ~id |> Handler_utils.or_person_error in
  Handler_utils.json_response (Model.Person.to_json person)

type create_request = { name : string } [@@deriving yojson]

let create request =
  let* { name } =
    Handler_utils.parse_json_body create_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  if String.trim name = "" then Handler_utils.bad_request "Name cannot be empty"
  else
    let* person =
      Service.Person.create ~name |> Handler_utils.or_person_error
    in
    Handler_utils.json_response ~status:`Created (Model.Person.to_json person)

type update_request = { name : string } [@@deriving yojson]

let update request id =
  let* { name } =
    Handler_utils.parse_json_body update_request_of_yojson request
    |> Handler_utils.or_bad_request
  in
  if String.trim name = "" then Handler_utils.bad_request "Name cannot be empty"
  else
    let* person =
      Service.Person.update ~id ~name |> Handler_utils.or_person_error
    in
    Handler_utils.json_response (Model.Person.to_json person)

let delete_person _request id =
  let* () = Service.Person.delete ~id |> Handler_utils.or_person_error in
  Response.of_string ~body:"" `No_content

let routes () =
  let open Tapak.Router in
  [
    get (s "persons")
    |> guard Pagination.Pagination.pagination_guard
    |> request |> into list;
    get (s "persons" / int) |> request |> into get_person;
    post (s "persons") |> request |> into create;
    put (s "persons" / int) |> request |> into update;
    delete (s "persons" / int) |> request |> into delete_person;
  ]
