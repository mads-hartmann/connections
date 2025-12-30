type t = { id : int; name : string; tags : Tag.t list; metadata : Person_metadata.t list }

type t_with_counts = {
  id : int;
  name : string;
  tags : Tag.t list;
  feed_count : int;
  article_count : int;
  metadata : Person_metadata.t list;
}

(* t_with_counts accessors - defined first so t accessors take precedence *)
let id_with_counts (t : t_with_counts) = t.id
let name_with_counts (t : t_with_counts) = t.name
let tags_with_counts (t : t_with_counts) = t.tags
let feed_count (t : t_with_counts) = t.feed_count
let article_count (t : t_with_counts) = t.article_count
let metadata_with_counts (t : t_with_counts) = t.metadata
let create_with_counts ~id ~name ~tags ~feed_count ~article_count ~metadata =
  { id; name; tags; feed_count; article_count; metadata }
let with_metadata_counts (t : t_with_counts) metadata = { t with metadata }

(* t accessors - defined last so they match the .mli signature *)
let id (t : t) = t.id
let name (t : t) = t.name
let tags (t : t) = t.tags
let metadata (t : t) = t.metadata
let create ~id ~name ~tags ~metadata = { id; name; tags; metadata }
let with_metadata (t : t) metadata = { t with metadata }

let to_json (t : t) =
  `Assoc
    [
      ("id", `Int t.id);
      ("name", `String t.name);
      ("tags", `List (List.map Tag.yojson_of_t t.tags));
      ("metadata", `List (List.map Person_metadata.to_json t.metadata));
    ]

let to_json_with_counts (t : t_with_counts) =
  `Assoc
    [
      ("id", `Int t.id);
      ("name", `String t.name);
      ("tags", `List (List.map Tag.yojson_of_t t.tags));
      ("feed_count", `Int t.feed_count);
      ("article_count", `Int t.article_count);
      ("metadata", `List (List.map Person_metadata.to_json t.metadata));
    ]

let paginated_to_json response = Shared.Paginated.to_json to_json response

let paginated_with_counts_to_json response =
  Shared.Paginated.to_json to_json_with_counts response

let error_to_json = Shared.error_to_json

(* t_with_counts pp/equal - defined first *)
let pp_with_counts fmt (t : t_with_counts) =
  Format.fprintf fmt
    "{ id = %d; name = %S; tags = [%d items]; feed_count = %d; article_count = %d; metadata = [%d items] }"
    t.id t.name (List.length t.tags) t.feed_count t.article_count (List.length t.metadata)

let equal_with_counts (a : t_with_counts) (b : t_with_counts) =
  Int.equal a.id b.id
  && String.equal a.name b.name
  && List.equal Tag.equal a.tags b.tags
  && Int.equal a.feed_count b.feed_count
  && Int.equal a.article_count b.article_count
  && List.equal Person_metadata.equal a.metadata b.metadata

(* t pp/equal - defined last to match .mli *)
let pp fmt (t : t) =
  Format.fprintf fmt "{ id = %d; name = %S; tags = [%d items]; metadata = [%d items] }"
    t.id t.name (List.length t.tags) (List.length t.metadata)

let equal (a : t) (b : t) =
  Int.equal a.id b.id
  && String.equal a.name b.name
  && List.equal Tag.equal a.tags b.tags
  && List.equal Person_metadata.equal a.metadata b.metadata
