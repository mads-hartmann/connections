type create_error = [ `Invalid_field_type | `Caqti of Caqti_error.t ]

val find_existing :
  connection_id:int ->
  field_type_id:int ->
  value:string ->
  (Model.Connection_metadata.t option, Caqti_error.t) result

val create :
  connection_id:int ->
  field_type_id:int ->
  value:string ->
  (Model.Connection_metadata.t, create_error) result

val get : id:int -> (Model.Connection_metadata.t option, Caqti_error.t) result

val get_for_connection :
  id:int ->
  connection_id:int ->
  (Model.Connection_metadata.t option, Caqti_error.t) result

val list_by_connection :
  connection_id:int -> (Model.Connection_metadata.t list, Caqti_error.t) result

val update :
  id:int ->
  value:string ->
  (Model.Connection_metadata.t option, Caqti_error.t) result

val delete : id:int -> (bool, Caqti_error.t) result
val delete_for_connection : id:int -> connection_id:int -> (bool, Caqti_error.t) result
