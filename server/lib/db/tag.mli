val create : name:string -> (Model.Tag.t, Caqti_error.t) result
val get : id:int -> (Model.Tag.t option, Caqti_error.t) result
val get_by_name : name:string -> (Model.Tag.t option, Caqti_error.t) result
val get_or_create : name:string -> (Model.Tag.t, Caqti_error.t) result
val list_all : unit -> (Model.Tag.t list, Caqti_error.t) result

val list :
  page:int ->
  per_page:int ->
  ?query:string ->
  unit ->
  (Model.Tag.t Model.Shared.Paginated.t, Caqti_error.t) result

val delete : id:int -> (bool, Caqti_error.t) result
val update : id:int -> name:string -> (Model.Tag.t option, Caqti_error.t) result
val add_to_connection : connection_id:int -> tag_id:int -> (unit, Caqti_error.t) result

val remove_from_connection :
  connection_id:int -> tag_id:int -> (unit, Caqti_error.t) result

val get_by_connection : connection_id:int -> (Model.Tag.t list, Caqti_error.t) result
val add_to_feed : feed_id:int -> tag_id:int -> (unit, Caqti_error.t) result
val remove_from_feed : feed_id:int -> tag_id:int -> (unit, Caqti_error.t) result
val get_by_feed : feed_id:int -> (Model.Tag.t list, Caqti_error.t) result

val add_to_uri :
  uri_id:int -> tag_id:int -> (unit, Caqti_error.t) result

val remove_from_uri :
  uri_id:int -> tag_id:int -> (unit, Caqti_error.t) result

val get_by_uri : uri_id:int -> (Model.Tag.t list, Caqti_error.t) result
