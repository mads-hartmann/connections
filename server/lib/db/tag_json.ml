(* Parse JSON-encoded tags from SQLite json_group_array results *)

let int_of_json = function `Int i -> Some i | _ -> None
let string_of_json = function `String s -> Some s | _ -> None

let parse_tag_object = function
  | `Assoc fields ->
      let id = Option.bind (List.assoc_opt "id" fields) int_of_json in
      let name = Option.bind (List.assoc_opt "name" fields) string_of_json in
      (match (id, name) with
      | Some id, Some name -> Some { Model.Tag.id; name }
      | _ -> None)
  | _ -> None

let parse (json_str : string) : Model.Tag.t list =
  try
    match Yojson.Safe.from_string json_str with
    | `List items -> List.filter_map parse_tag_object items
    | _ -> []
  with _ -> []
