module Error : sig
  type t = Not_found | Already_exists | Database of Caqti_error.t

  val pp : Format.formatter -> t -> unit
  val to_string : t -> string
end

val get : id:int -> (Model.Article.t, Error.t) result
val get_by_url : url:string -> (Model.Article.t option, Error.t) result

type create_input = {
  url : string;
  person_id : int option;
  title : string option;
  published_at : string option;
  content : string option;
  author : string option;
  image_url : string option;
}

val create : create_input -> (Model.Article.t, Error.t) result

val list_all :
  page:int ->
  per_page:int ->
  unread_only:bool ->
  read_later_only:bool ->
  tag:string option ->
  ?query:string ->
  unit ->
  (Model.Article.t Model.Shared.Paginated.t, Error.t) result

val list_by_feed :
  feed_id:int ->
  page:int ->
  per_page:int ->
  (Model.Article.t Model.Shared.Paginated.t, Error.t) result

val list_by_person :
  person_id:int ->
  page:int ->
  per_page:int ->
  unread_only:bool ->
  (Model.Article.t Model.Shared.Paginated.t, Error.t) result

val mark_read : id:int -> read:bool -> (Model.Article.t, Error.t) result
val mark_read_later : id:int -> read_later:bool -> (Model.Article.t, Error.t) result
val mark_all_read : feed_id:int -> (int, Error.t) result
val mark_all_read_global : unit -> (int, Error.t) result
val delete : id:int -> (unit, Error.t) result
