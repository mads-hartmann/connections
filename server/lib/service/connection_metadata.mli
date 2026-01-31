module Error : sig
  type t =
    | Not_found
    | Connection_not_found
    | Invalid_field_type
    | Database of Caqti_error.t

  val pp : Format.formatter -> t -> unit
  val to_string : t -> string
end

val create :
  connection_id:int ->
  field_type_id:int ->
  value:string ->
  (Model.Connection_metadata.t, Error.t) result

val get : id:int -> (Model.Connection_metadata.t, Error.t) result

val list_by_connection :
  connection_id:int -> (Model.Connection_metadata.t list, Error.t) result

val update :
  id:int ->
  connection_id:int ->
  value:string ->
  (Model.Connection_metadata.t, Error.t) result

val delete : id:int -> connection_id:int -> (unit, Error.t) result
