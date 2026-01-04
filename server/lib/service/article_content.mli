(** Article content service - read-through cache for markdown content *)

module Error : sig
  type t =
    | Article_not_found
    | Fetch_failed of string
    | Database of Caqti_error.t

  val pp : Format.formatter -> t -> unit
  val to_string : t -> string
end

val get :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  article_id:int ->
  (string, Error.t) result
(** Get markdown content for an article. Returns cached content if available,
    otherwise fetches the article URL, converts to markdown, and caches. *)

val invalidate : article_id:int -> (unit, Error.t) result
(** Remove cached content for an article, forcing re-fetch on next access. *)
