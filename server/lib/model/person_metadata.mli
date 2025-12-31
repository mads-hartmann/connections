type t

val id : t -> int
val person_id : t -> int
val field_type : t -> Metadata_field_type.t
val value : t -> string

val create :
  id:int ->
  person_id:int ->
  field_type:Metadata_field_type.t ->
  value:string ->
  t

val to_json : t -> Yojson.Safe.t
val compare_by_field_type_name : t -> t -> int
val sort_by_field_type_name : t list -> t list
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
