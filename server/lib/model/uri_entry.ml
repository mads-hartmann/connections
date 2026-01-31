type t = {
  id : int;
  feed_id : int option;
  connection_id : int option;
  connection_name : string option; [@yojson.option]
  kind : Uri_kind.t;
  title : string option; [@yojson.option]
  url : string;
  published_at : string option; [@yojson.option]
  content : string option; [@yojson.option]
  author : string option; [@yojson.option]
  image_url : string option; [@yojson.option]
  created_at : string;
  read_at : string option;
  read_later_at : string option;
  tags : Tag.t list;
  og_title : string option; [@yojson.option]
  og_description : string option; [@yojson.option]
  og_image : string option; [@yojson.option]
  og_site_name : string option; [@yojson.option]
  og_fetched_at : string option; [@yojson.option]
  og_fetch_error : string option; [@yojson.option]
}

let id t = t.id
let feed_id t = t.feed_id
let connection_id t = t.connection_id
let connection_name t = t.connection_name
let kind t = t.kind
let title t = t.title
let url t = t.url
let published_at t = t.published_at
let content t = t.content
let author t = t.author
let image_url t = t.image_url
let created_at t = t.created_at
let read_at t = t.read_at
let read_later_at t = t.read_later_at
let tags t = t.tags
let og_title t = t.og_title
let og_description t = t.og_description
let og_image t = t.og_image
let og_site_name t = t.og_site_name
let og_fetched_at t = t.og_fetched_at
let og_fetch_error t = t.og_fetch_error

let create ~id ~feed_id ~connection_id ~connection_name ~kind ~title ~url
    ~published_at ~content ~author ~image_url ~created_at ~read_at ~read_later_at
    ~tags ~og_title ~og_description ~og_image ~og_site_name ~og_fetched_at
    ~og_fetch_error =
  {
    id;
    feed_id;
    connection_id;
    connection_name;
    kind;
    title;
    url;
    published_at;
    content;
    author;
    image_url;
    created_at;
    read_at;
    read_later_at;
    tags;
    og_title;
    og_description;
    og_image;
    og_site_name;
    og_fetched_at;
    og_fetch_error;
  }

let nullable_string_to_json = function
  | Some v -> `String v
  | None -> `Null

let nullable_int_to_json = function
  | Some v -> `Int v
  | None -> `Null

let to_json t =
  `Assoc
    ([
       ("id", `Int t.id);
       ("feed_id", nullable_int_to_json t.feed_id);
       ("connection_id", nullable_int_to_json t.connection_id);
       ("connection_name", nullable_string_to_json t.connection_name);
       ("kind", Uri_kind.yojson_of_t t.kind);
       ("title", nullable_string_to_json t.title);
       ("url", `String t.url);
       ("published_at", nullable_string_to_json t.published_at);
       ("content", nullable_string_to_json t.content);
       ("author", nullable_string_to_json t.author);
       ("image_url", nullable_string_to_json t.image_url);
       ("created_at", `String t.created_at);
       ("read_at", nullable_string_to_json t.read_at);
       ("read_later_at", nullable_string_to_json t.read_later_at);
       ("tags", `List (List.map Tag.yojson_of_t t.tags));
       ("og_title", nullable_string_to_json t.og_title);
       ("og_description", nullable_string_to_json t.og_description);
       ("og_image", nullable_string_to_json t.og_image);
       ("og_site_name", nullable_string_to_json t.og_site_name);
       ("og_fetched_at", nullable_string_to_json t.og_fetched_at);
       ("og_fetch_error", nullable_string_to_json t.og_fetch_error);
     ])

let paginated_to_json response = Shared.Paginated.to_json to_json response
let error_to_json = Shared.error_to_json

let pp fmt t =
  Format.fprintf fmt
    "{ id = %d; feed_id = %a; connection_id = %a; kind = %a; title = %a; url = \
     %S; read_later_at = %a }"
    t.id
    (Format.pp_print_option Format.pp_print_int)
    t.feed_id
    (Format.pp_print_option Format.pp_print_int)
    t.connection_id Uri_kind.pp t.kind
    (Format.pp_print_option Format.pp_print_string)
    t.title t.url
    (Format.pp_print_option Format.pp_print_string)
    t.read_later_at

let equal a b =
  Int.equal a.id b.id
  && Option.equal Int.equal a.feed_id b.feed_id
  && Option.equal Int.equal a.connection_id b.connection_id
  && Option.equal String.equal a.connection_name b.connection_name
  && Uri_kind.equal a.kind b.kind
  && Option.equal String.equal a.title b.title
  && String.equal a.url b.url
  && Option.equal String.equal a.published_at b.published_at
  && Option.equal String.equal a.content b.content
  && Option.equal String.equal a.author b.author
  && Option.equal String.equal a.image_url b.image_url
  && String.equal a.created_at b.created_at
  && Option.equal String.equal a.read_at b.read_at
  && Option.equal String.equal a.read_later_at b.read_later_at
  && List.equal Tag.equal a.tags b.tags
  && Option.equal String.equal a.og_title b.og_title
  && Option.equal String.equal a.og_description b.og_description
  && Option.equal String.equal a.og_image b.og_image
  && Option.equal String.equal a.og_site_name b.og_site_name
  && Option.equal String.equal a.og_fetched_at b.og_fetched_at
  && Option.equal String.equal a.og_fetch_error b.og_fetch_error
