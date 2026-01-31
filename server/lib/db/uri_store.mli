val get : id:int -> (Model.Uri_entry.t option, Caqti_error.t) result

val list_by_feed :
  feed_id:int ->
  page:int ->
  per_page:int ->
  (Model.Uri_entry.t Model.Shared.Paginated.t, Caqti_error.t) result

val list_by_connection :
  connection_id:int ->
  page:int ->
  per_page:int ->
  unread_only:bool ->
  (Model.Uri_entry.t Model.Shared.Paginated.t, Caqti_error.t) result

val list_all :
  page:int ->
  per_page:int ->
  unread_only:bool ->
  read_later_only:bool ->
  tag:string option ->
  orphan_only:bool ->
  ?query:string ->
  unit ->
  (Model.Uri_entry.t Model.Shared.Paginated.t, Caqti_error.t) result

val upsert :
  feed_id:int ->
  connection_id:int option ->
  kind:Model.Uri_kind.t ->
  title:string option ->
  url:string ->
  published_at:string option ->
  content:string option ->
  author:string option ->
  image_url:string option ->
  (Model.Uri_entry.t, Caqti_error.t) result

val create :
  connection_id:int option ->
  kind:Model.Uri_kind.t ->
  url:string ->
  title:string option ->
  (Model.Uri_entry.t, Caqti_error.t) result

val update :
  id:int ->
  connection_id:int option ->
  kind:Model.Uri_kind.t ->
  title:string option ->
  (Model.Uri_entry.t option, Caqti_error.t) result

val mark_read :
  id:int -> read:bool -> (Model.Uri_entry.t option, Caqti_error.t) result

val mark_read_later :
  id:int -> read_later:bool -> (Model.Uri_entry.t option, Caqti_error.t) result

val mark_all_read : feed_id:int -> (int, Caqti_error.t) result
val mark_all_read_global : unit -> (int, Caqti_error.t) result
val mark_all_read_by_connection : connection_id:int -> (int, Caqti_error.t) result
val delete : id:int -> (bool, Caqti_error.t) result
val delete_by_connection_id : connection_id:int -> (unit, Caqti_error.t) result

val update_og_metadata :
  id:int ->
  og_title:string option ->
  og_description:string option ->
  og_image:string option ->
  og_site_name:string option ->
  og_fetch_error:string option ->
  (Model.Uri_entry.t option, Caqti_error.t) result

val list_needing_og_metadata :
  limit:int -> (Model.Uri_entry.t list, Caqti_error.t) result
