val create :
  person_id:int ->
  url:string ->
  title:string option ->
  (Model.Rss_feed.t option, Caqti_error.t) result

val get : id:int -> (Model.Rss_feed.t option, Caqti_error.t) result

val list_by_person :
  person_id:int ->
  page:int ->
  per_page:int ->
  (Model.Rss_feed.t Model.Shared.Paginated.t, Caqti_error.t) result

val update :
  id:int ->
  url:string option ->
  title:string option ->
  (Model.Rss_feed.t option, Caqti_error.t) result

val delete : id:int -> (bool, Caqti_error.t) result
val list_all : unit -> (Model.Rss_feed.t list, Caqti_error.t) result

val list_all_paginated :
  page:int ->
  per_page:int ->
  ?query:string ->
  unit ->
  (Model.Rss_feed.t Model.Shared.Paginated.t, Caqti_error.t) result

val update_last_fetched : id:int -> (unit, Caqti_error.t) result
