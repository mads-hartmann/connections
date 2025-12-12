open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = {
  id : int;
  feed_id : int;
  title : string option; [@yojson.option]
  url : string;
  published_at : string option; [@yojson.option]
  content : string option; [@yojson.option]
  author : string option; [@yojson.option]
  image_url : string option; [@yojson.option]
  created_at : string;
  read_at : string option;
}
[@@deriving yojson]

type create_input = {
  feed_id : int;
  title : string option;
  url : string;
  published_at : string option;
  content : string option;
  author : string option;
  image_url : string option;
}

type mark_read_request = { read : bool } [@@deriving yojson]

type paginated_response = {
  data : t list;
  page : int;
  per_page : int;
  total : int;
  total_pages : int;
}
[@@deriving yojson]

type error_response = { error : string } [@@deriving yojson]

let to_json article = yojson_of_t article
let of_json json = t_of_yojson json
let list_to_json articles = `List (List.map yojson_of_t articles)
let paginated_to_json response = yojson_of_paginated_response response
let error_to_json msg = yojson_of_error_response { error = msg }
