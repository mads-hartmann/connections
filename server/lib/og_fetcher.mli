val fetch_for_article :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  Model.Article.t ->
  (Model.Article.t option, Caqti_error.t) result

val stop : unit -> unit
val start : sw:Eio.Switch.t -> env:Eio_unix.Stdenv.base -> unit
