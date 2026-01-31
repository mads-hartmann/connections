open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = {
  id : int;
  connection_id : int;
  url : string;
  title : string option; [@yojson.option]
  created_at : string;
  last_fetched_at : string option; [@yojson.option]
  tags : Tag.t list;
}
[@@deriving yojson]

let id t = t.id
let connection_id t = t.connection_id
let url t = t.url
let title t = t.title
let created_at t = t.created_at
let last_fetched_at t = t.last_fetched_at
let tags t = t.tags

let create ~id ~connection_id ~url ~title ~created_at ~last_fetched_at ~tags =
  { id; connection_id; url; title; created_at; last_fetched_at; tags }

let to_json = yojson_of_t
let of_json = t_of_yojson
let paginated_to_json response = Shared.Paginated.to_json yojson_of_t response
let error_to_json = Shared.error_to_json

let pp fmt t =
  Format.fprintf fmt "{ id = %d; connection_id = %d; url = %S; title = %a }" t.id
    t.connection_id t.url
    (Format.pp_print_option Format.pp_print_string)
    t.title

let equal a b =
  Int.equal a.id b.id
  && Int.equal a.connection_id b.connection_id
  && String.equal a.url b.url
  && Option.equal String.equal a.title b.title
  && String.equal a.created_at b.created_at
  && Option.equal String.equal a.last_fetched_at b.last_fetched_at
  && List.equal Tag.equal a.tags b.tags
