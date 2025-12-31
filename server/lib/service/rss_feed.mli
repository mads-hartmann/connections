module Error : sig
  type t = Not_found | Database of Caqti_error.t

  val pp : Format.formatter -> t -> unit
  val to_string : t -> string
end

val create :
  person_id:int ->
  url:string ->
  title:string option ->
  (Model.Rss_feed.t, Error.t) result

val get : id:int -> (Model.Rss_feed.t, Error.t) result

val list_by_person :
  person_id:int ->
  page:int ->
  per_page:int ->
  (Model.Rss_feed.t Model.Shared.Paginated.t, Error.t) result

val list_all_paginated :
  page:int ->
  per_page:int ->
  ?query:string ->
  unit ->
  (Model.Rss_feed.t Model.Shared.Paginated.t, Error.t) result

val update :
  id:int ->
  url:string option ->
  title:string option ->
  (Model.Rss_feed.t, Error.t) result

val delete : id:int -> (unit, Error.t) result
