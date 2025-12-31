module Error : sig
  type t =
    | Not_found
    | Person_not_found
    | Invalid_field_type
    | Database of Caqti_error.t

  val pp : Format.formatter -> t -> unit
  val to_string : t -> string
end

val create :
  person_id:int ->
  field_type_id:int ->
  value:string ->
  (Model.Person_metadata.t, Error.t) result

val get : id:int -> (Model.Person_metadata.t, Error.t) result

val list_by_person :
  person_id:int -> (Model.Person_metadata.t list, Error.t) result

val update :
  id:int ->
  person_id:int ->
  value:string ->
  (Model.Person_metadata.t, Error.t) result

val delete : id:int -> person_id:int -> (unit, Error.t) result
