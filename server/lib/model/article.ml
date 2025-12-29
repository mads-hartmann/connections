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
  tags : Tag.t list;
  og_title : string option; [@yojson.option]
  og_description : string option; [@yojson.option]
  og_image : string option; [@yojson.option]
  og_site_name : string option; [@yojson.option]
  og_fetched_at : string option; [@yojson.option]
  og_fetch_error : string option; [@yojson.option]
}
[@@deriving yojson]

let to_json = yojson_of_t
let of_json = t_of_yojson
let paginated_to_json response = Shared.Paginated.to_json yojson_of_t response
let error_to_json = Shared.error_to_json
