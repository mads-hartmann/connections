open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = {
  id : int;
  person_id : int;
  url : string;
  title : string option; [@yojson.option]
  created_at : string;
  last_fetched_at : string option; [@yojson.option]
  tags : Tag.t list;
}
[@@deriving yojson]

let to_json = yojson_of_t
let of_json = t_of_yojson
let paginated_to_json response = Shared.Paginated.to_json yojson_of_t response
let error_to_json = Shared.error_to_json
