open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = {
  id : int;
  person_id : int;
  url : string;
  title : string option; [@yojson.option]
  created_at : string;
  last_fetched_at : string option; [@yojson.option]
}
[@@deriving yojson]

type create_request = {
  person_id : int;
  url : string;
  title : string option; [@yojson.option]
}
[@@deriving yojson]

type update_request = {
  url : string option; [@yojson.option]
  title : string option; [@yojson.option]
}
[@@deriving yojson]

type paginated_response = {
  data : t list;
  page : int;
  per_page : int;
  total : int;
  total_pages : int;
}
[@@deriving yojson]

type error_response = { error : string } [@@deriving yojson]

let to_json rss_feed = yojson_of_t rss_feed
let of_json json = t_of_yojson json
let list_to_json rss_feeds = `List (List.map yojson_of_t rss_feeds)
let paginated_to_json response = yojson_of_paginated_response response
let error_to_json msg = yojson_of_error_response { error = msg }
