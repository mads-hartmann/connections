type create_input = {
  feed_id : int option;
  person_id : int option;
  title : string option;
  url : string;
  published_at : string option;
  content : string option;
  author : string option;
  image_url : string option;
}

type og_metadata_input = {
  og_title : string option;
  og_description : string option;
  og_image : string option;
  og_site_name : string option;
  og_fetch_error : string option;
}

val upsert : create_input -> (unit, Caqti_error.t) result
val upsert_many : create_input list -> (int, Caqti_error.t) result
val create : create_input -> (Model.Article.t, Caqti_error.t) result
val get : id:int -> (Model.Article.t option, Caqti_error.t) result

val get_by_feed_url :
  feed_id:int -> url:string -> (Model.Article.t option, Caqti_error.t) result

val get_by_url : url:string -> (Model.Article.t option, Caqti_error.t) result

val list_by_feed :
  feed_id:int ->
  page:int ->
  per_page:int ->
  (Model.Article.t Model.Shared.Paginated.t, Caqti_error.t) result

val list_all :
  page:int ->
  per_page:int ->
  unread_only:bool ->
  read_later_only:bool ->
  ?query:string ->
  unit ->
  (Model.Article.t Model.Shared.Paginated.t, Caqti_error.t) result

val list_by_tag :
  tag:string ->
  page:int ->
  per_page:int ->
  unread_only:bool ->
  (Model.Article.t Model.Shared.Paginated.t, Caqti_error.t) result

val list_by_person :
  person_id:int ->
  page:int ->
  per_page:int ->
  unread_only:bool ->
  (Model.Article.t Model.Shared.Paginated.t, Caqti_error.t) result

val list_needing_og_fetch :
  limit:int -> (Model.Article.t list, Caqti_error.t) result

val update_og_metadata :
  id:int -> og_metadata_input -> (Model.Article.t option, Caqti_error.t) result

val mark_read :
  id:int -> read:bool -> (Model.Article.t option, Caqti_error.t) result

val mark_all_read : feed_id:int -> (int, Caqti_error.t) result
val mark_all_read_global : unit -> (int, Caqti_error.t) result

val mark_read_later :
  id:int -> read_later:bool -> (Model.Article.t option, Caqti_error.t) result

val delete : id:int -> (bool, Caqti_error.t) result
val delete_by_person_id : person_id:int -> (unit, Caqti_error.t) result
