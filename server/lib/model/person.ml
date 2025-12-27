type t = { id : int; name : string; tags : Tag.t list; metadata : Person_metadata.t list }

type t_with_counts = {
  id : int;
  name : string;
  tags : Tag.t list;
  feed_count : int;
  article_count : int;
  metadata : Person_metadata.t list;
}

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
