val json_response : ?status:Piaf.Status.t -> Yojson.Safe.t -> Tapak.Response.t
val error_response : Piaf.Status.t -> string -> Tapak.Response.t
val bad_request : string -> Tapak.Response.t
val not_found : string -> Tapak.Response.t
val internal_error : string -> Tapak.Response.t
val is_valid_url : string -> bool
val validate_url : string -> (string, string) result
val parse_query_int : string -> int -> Tapak.Request.t -> int
val query : string -> Tapak.Request.t -> string option

val parse_json_body :
  (Yojson.Safe.t -> 'a) -> Tapak.Request.t -> ('a, string) result

module Syntax : sig
  val ( let* ) :
    ('a, Tapak.Response.t) result ->
    ('a -> Tapak.Response.t) ->
    Tapak.Response.t
end

val or_bad_request : ('a, string) result -> ('a, Tapak.Response.t) result
val or_internal_error : ('a, string) result -> ('a, Tapak.Response.t) result
val or_not_found : string -> 'a option -> ('a, Tapak.Response.t) result
val or_bad_request_opt : string -> 'a option -> ('a, Tapak.Response.t) result
val or_db_error : ('a, Caqti_error.t) result -> ('a, Tapak.Response.t) result

val or_article_error :
  ('a, Service.Article.Error.t) result -> ('a, Tapak.Response.t) result

val or_feed_error :
  ('a, Service.Rss_feed.Error.t) result -> ('a, Tapak.Response.t) result

val or_person_error :
  ('a, Service.Person.Error.t) result -> ('a, Tapak.Response.t) result

val or_tag_error :
  ('a, Service.Tag.Error.t) result -> ('a, Tapak.Response.t) result

val or_person_metadata_error :
  ('a, Service.Person_metadata.Error.t) result -> ('a, Tapak.Response.t) result

val or_article_content_error :
  ('a, Service.Article_content.Error.t) result -> ('a, Tapak.Response.t) result
