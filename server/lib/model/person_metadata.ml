type t = { id : int; person_id : int; field_type : Metadata_field_type.t; value : string }

let to_json t =
  `Assoc
    [
      ("id", `Int t.id);
      ("field_type", Metadata_field_type.to_json_with_id t.field_type);
      ("value", `String t.value);
    ]

let compare_by_field_type_name a b =
  String.compare
    (Metadata_field_type.name a.field_type)
    (Metadata_field_type.name b.field_type)

let sort_by_field_type_name items = List.sort compare_by_field_type_name items
