module Error : sig
  type t = Not_found | Database of Caqti_error.t

  val pp : Format.formatter -> t -> unit
  val to_string : t -> string
end

val get : id:int -> (Model.Uri_entry.t, Error.t) result

val create :
  connection_id:int option ->
  kind:Model.Uri_kind.t ->
  url:string ->
  title:string option ->
  (Model.Uri_entry.t, Error.t) result

val update :
  id:int ->
  connection_id:int option ->
  kind:Model.Uri_kind.t ->
  title:string option ->
  (Model.Uri_entry.t, Error.t) result

val list_all :
  page:int ->
  per_page:int ->
  unread_only:bool ->
  read_later_only:bool ->
  tag:string option ->
  orphan_only:bool ->
  ?query:string ->
  unit ->
  (Model.Uri_entry.t Model.Shared.Paginated.t, Error.t) result

val list_by_feed :
  feed_id:int ->
  page:int ->
  per_page:int ->
  (Model.Uri_entry.t Model.Shared.Paginated.t, Error.t) result

val list_by_connection :
  connection_id:int ->
  page:int ->
  per_page:int ->
  unread_only:bool ->
  (Model.Uri_entry.t Model.Shared.Paginated.t, Error.t) result

val mark_read : id:int -> read:bool -> (Model.Uri_entry.t, Error.t) result
val mark_read_later : id:int -> read_later:bool -> (Model.Uri_entry.t, Error.t) result
val mark_all_read : feed_id:int -> (int, Error.t) result
val mark_all_read_global : unit -> (int, Error.t) result
val mark_all_read_by_connection : connection_id:int -> (int, Error.t) result
val delete : id:int -> (unit, Error.t) result
