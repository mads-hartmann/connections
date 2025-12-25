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

type with_tags = {
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
}
[@@deriving yojson]

let to_json = yojson_of_t
let of_json = t_of_yojson
let with_tags_to_json = yojson_of_with_tags

let paginated_with_tags_to_json response =
  Shared.Paginated.to_json yojson_of_with_tags response

let paginated_to_json response = Shared.Paginated.to_json yojson_of_t response
let error_to_json = Shared.error_to_json

let add_tags (article : t) (tags : Tag.t list) : with_tags =
  {
    id = article.id;
    feed_id = article.feed_id;
    title = article.title;
    url = article.url;
    published_at = article.published_at;
    content = article.content;
    author = article.author;
    image_url = article.image_url;
    created_at = article.created_at;
    read_at = article.read_at;
    tags;
  }
