(** Article content cache - stores markdown conversion of article HTML *)

val get_by_article_id :
  article_id:int -> ((int * string) option, Caqti_error.t) result
(** Returns (id, markdown) if cached content exists for the article *)

val upsert : article_id:int -> markdown:string -> (unit, Caqti_error.t) result
(** Insert or update cached markdown content for an article *)

val delete_by_article_id : article_id:int -> (unit, Caqti_error.t) result
(** Delete cached content for an article *)
