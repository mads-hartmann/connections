module Error : sig
  type t = Not_found | Database of Caqti_error.t

  val pp : Format.formatter -> t -> unit
  val to_string : t -> string
end

val create :
  name:string -> ?photo:string -> unit -> (Model.Connection.t, Error.t) result

val get : id:int -> (Model.Connection.t, Error.t) result

val list :
  page:int ->
  per_page:int ->
  ?query:string ->
  unit ->
  (Model.Connection.t Model.Shared.Paginated.t, Error.t) result

val list_with_counts :
  page:int ->
  per_page:int ->
  ?query:string ->
  unit ->
  (Model.Connection.t_with_counts Model.Shared.Paginated.t, Error.t) result

val update :
  id:int ->
  name:string ->
  photo:string option ->
  (Model.Connection.t, Error.t) result

val delete : id:int -> (unit, Error.t) result
