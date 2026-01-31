type t = {
  id : int;
  name : string;
  photo : string option;
  tags : Tag.t list;
  metadata : Connection_metadata.t list;
}

type t_with_counts = {
  id : int;
  name : string;
  photo : string option;
  tags : Tag.t list;
  feed_count : int;
  uri_count : int;
  unread_uri_count : int;
  metadata : Connection_metadata.t list;
}

(* t_with_counts accessors - defined first so t accessors take precedence *)
let id_with_counts (t : t_with_counts) = t.id
let name_with_counts (t : t_with_counts) = t.name
let photo_with_counts (t : t_with_counts) = t.photo
let tags_with_counts (t : t_with_counts) = t.tags
let feed_count (t : t_with_counts) = t.feed_count
let uri_count (t : t_with_counts) = t.uri_count
let unread_uri_count (t : t_with_counts) = t.unread_uri_count
let metadata_with_counts (t : t_with_counts) = t.metadata

let create_with_counts ~id ~name ~photo ~tags ~feed_count ~uri_count
    ~unread_uri_count ~metadata =
  {
    id;
    name;
    photo;
    tags;
    feed_count;
    uri_count;
    unread_uri_count;
    metadata;
  }

let with_metadata_counts (t : t_with_counts) metadata = { t with metadata }

(* t accessors - defined last so they match the .mli signature *)
let id (t : t) = t.id
let name (t : t) = t.name
let photo (t : t) = t.photo
let tags (t : t) = t.tags
let metadata (t : t) = t.metadata
let create ~id ~name ~photo ~tags ~metadata = { id; name; photo; tags; metadata }
let with_metadata (t : t) metadata = { t with metadata }

let photo_to_json photo =
  match photo with Some p -> [ ("photo", `String p) ] | None -> []

let to_json (t : t) =
  `Assoc
    ([
       ("id", `Int t.id);
       ("name", `String t.name);
     ]
    @ photo_to_json t.photo
    @ [
        ("tags", `List (List.map Tag.yojson_of_t t.tags));
        ("metadata", `List (List.map Connection_metadata.to_json t.metadata));
      ])

let to_json_with_counts (t : t_with_counts) =
  `Assoc
    ([
       ("id", `Int t.id);
       ("name", `String t.name);
     ]
    @ photo_to_json t.photo
    @ [
        ("tags", `List (List.map Tag.yojson_of_t t.tags));
        ("feed_count", `Int t.feed_count);
        ("uri_count", `Int t.uri_count);
        ("unread_uri_count", `Int t.unread_uri_count);
        ("metadata", `List (List.map Connection_metadata.to_json t.metadata));
      ])

let paginated_to_json response = Shared.Paginated.to_json to_json response

let paginated_with_counts_to_json response =
  Shared.Paginated.to_json to_json_with_counts response

let error_to_json = Shared.error_to_json

(* t_with_counts pp/equal - defined first *)
let pp_with_counts fmt (t : t_with_counts) =
  Format.fprintf fmt
    "{ id = %d; name = %S; photo = %a; tags = [%d items]; feed_count = %d; \
     uri_count = %d; unread_uri_count = %d; metadata = [%d items] }"
    t.id t.name
    (Format.pp_print_option Format.pp_print_string)
    t.photo (List.length t.tags) t.feed_count t.uri_count
    t.unread_uri_count (List.length t.metadata)

let equal_with_counts (a : t_with_counts) (b : t_with_counts) =
  Int.equal a.id b.id && String.equal a.name b.name
  && Option.equal String.equal a.photo b.photo
  && List.equal Tag.equal a.tags b.tags
  && Int.equal a.feed_count b.feed_count
  && Int.equal a.uri_count b.uri_count
  && Int.equal a.unread_uri_count b.unread_uri_count
  && List.equal Connection_metadata.equal a.metadata b.metadata

(* t pp/equal - defined last to match .mli *)
let pp fmt (t : t) =
  Format.fprintf fmt
    "{ id = %d; name = %S; photo = %a; tags = [%d items]; metadata = [%d items] \
     }"
    t.id t.name
    (Format.pp_print_option Format.pp_print_string)
    t.photo (List.length t.tags) (List.length t.metadata)

let equal (a : t) (b : t) =
  Int.equal a.id b.id && String.equal a.name b.name
  && Option.equal String.equal a.photo b.photo
  && List.equal Tag.equal a.tags b.tags
  && List.equal Connection_metadata.equal a.metadata b.metadata
