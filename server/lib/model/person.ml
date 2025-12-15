open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = { id : int; name : string } [@@deriving yojson]

type t_with_counts = {
  id : int;
  name : string;
  feed_count : int;
  article_count : int;
}
[@@deriving yojson]

type with_categories = {
  id : int;
  name : string;
  categories : Category.t list;
}
[@@deriving yojson]

type create_request = { name : string } [@@deriving yojson]
type update_request = { name : string } [@@deriving yojson]

let to_json = yojson_of_t
let of_json = t_of_yojson
let with_categories_to_json = yojson_of_with_categories
let paginated_to_json response = Shared.Paginated.to_json yojson_of_t response

let paginated_with_counts_to_json response =
  Shared.Paginated.to_json yojson_of_t_with_counts response

let error_to_json = Shared.error_to_json
