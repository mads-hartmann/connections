open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = { id : int; name : string } [@@deriving yojson]

type t_with_counts = {
  id : int;
  name : string;
  feed_count : int;
  article_count : int;
}
[@@deriving yojson]

type with_tags = { id : int; name : string; tags : Tag.t list }
[@@deriving yojson]

let to_json = yojson_of_t
let of_json = t_of_yojson
let with_tags_to_json = yojson_of_with_tags
let paginated_to_json response = Shared.Paginated.to_json yojson_of_t response

let paginated_with_counts_to_json response =
  Shared.Paginated.to_json yojson_of_t_with_counts response

let error_to_json = Shared.error_to_json
