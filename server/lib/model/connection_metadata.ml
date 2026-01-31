type t = {
  id : int;
  connection_id : int;
  field_type : Metadata_field_type.t;
  value : string;
}

let id t = t.id
let connection_id t = t.connection_id
let field_type t = t.field_type
let value t = t.value

let create ~id ~connection_id ~field_type ~value =
  { id; connection_id; field_type; value }

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

let pp fmt t =
  Format.fprintf fmt "{ id = %d; connection_id = %d; field_type = %a; value = %S }"
    t.id t.connection_id Metadata_field_type.pp t.field_type t.value

let equal a b =
  Int.equal a.id b.id
  && Int.equal a.connection_id b.connection_id
  && Metadata_field_type.equal a.field_type b.field_type
  && String.equal a.value b.value
