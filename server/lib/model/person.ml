open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = { id : int; name : string } [@@deriving yojson]

type t_with_counts = {
  id : int;
  name : string;
  feed_count : int;
  article_count : int;
}
[@@deriving yojson]

type create_request = { name : string } [@@deriving yojson]
type update_request = { name : string } [@@deriving yojson]

type paginated_response = {
  data : t list;
  page : int;
  per_page : int;
  total : int;
  total_pages : int;
}
[@@deriving yojson]

type paginated_response_with_counts = {
  data : t_with_counts list;
  page : int;
  per_page : int;
  total : int;
  total_pages : int;
}
[@@deriving yojson]

type error_response = { error : string } [@@deriving yojson]

let to_json person = yojson_of_t person
let of_json json = t_of_yojson json
let list_to_json persons = `List (List.map yojson_of_t persons)
let paginated_to_json response = yojson_of_paginated_response response

let paginated_with_counts_to_json response =
  yojson_of_paginated_response_with_counts response

let error_to_json msg = yojson_of_error_response { error = msg }
