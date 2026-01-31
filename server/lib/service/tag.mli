module Error : sig
  type t = Not_found | Database of Caqti_error.t

  val pp : Format.formatter -> t -> unit
  val to_string : t -> string
end

val create : name:string -> (Model.Tag.t, Error.t) result
val get : id:int -> (Model.Tag.t, Error.t) result

val list :
  page:int ->
  per_page:int ->
  ?query:string ->
  unit ->
  (Model.Tag.t Model.Shared.Paginated.t, Error.t) result

val delete : id:int -> (unit, Error.t) result
val update : id:int -> name:string -> (Model.Tag.t, Error.t) result

val add_to_connection : connection_id:int -> tag_id:int -> (unit, Error.t) result
val remove_from_connection : connection_id:int -> tag_id:int -> (unit, Error.t) result
val get_by_connection : connection_id:int -> (Model.Tag.t list, Error.t) result

val add_to_feed : feed_id:int -> tag_id:int -> (unit, Error.t) result
val remove_from_feed : feed_id:int -> tag_id:int -> (unit, Error.t) result
val get_by_feed : feed_id:int -> (Model.Tag.t list, Error.t) result

val add_to_uri : uri_id:int -> tag_id:int -> (unit, Error.t) result
val remove_from_uri : uri_id:int -> tag_id:int -> (unit, Error.t) result
val get_by_uri : uri_id:int -> (Model.Tag.t list, Error.t) result
