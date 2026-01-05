type create_error = [ `Invalid_field_type | `Caqti of Caqti_error.t ]

val find_existing :
  person_id:int ->
  field_type_id:int ->
  value:string ->
  (Model.Person_metadata.t option, Caqti_error.t) result

val create :
  person_id:int ->
  field_type_id:int ->
  value:string ->
  (Model.Person_metadata.t, create_error) result

val get : id:int -> (Model.Person_metadata.t option, Caqti_error.t) result

val get_for_person :
  id:int ->
  person_id:int ->
  (Model.Person_metadata.t option, Caqti_error.t) result

val list_by_person :
  person_id:int -> (Model.Person_metadata.t list, Caqti_error.t) result

val update :
  id:int ->
  value:string ->
  (Model.Person_metadata.t option, Caqti_error.t) result

val delete : id:int -> (bool, Caqti_error.t) result
val delete_for_person : id:int -> person_id:int -> (bool, Caqti_error.t) result
