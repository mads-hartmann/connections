val create :
  name:string -> ?photo:string -> unit -> (Model.Connection.t, Caqti_error.t) result

val get : id:int -> (Model.Connection.t option, Caqti_error.t) result

val list :
  page:int ->
  per_page:int ->
  ?query:string ->
  unit ->
  (Model.Connection.t Model.Shared.Paginated.t, Caqti_error.t) result

val list_with_counts :
  page:int ->
  per_page:int ->
  ?query:string ->
  unit ->
  (Model.Connection.t_with_counts Model.Shared.Paginated.t, Caqti_error.t) result

val update :
  id:int ->
  name:string ->
  photo:string option ->
  (Model.Connection.t option, Caqti_error.t) result

val delete : id:int -> (bool, Caqti_error.t) result
