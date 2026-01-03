(** Scheduled article metadata fetching. *)

val fetch_for_article :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  Model.Article.t ->
  (Model.Article.t option, Caqti_error.t) result
(** Fetch metadata for a single article immediately. *)

val start : sw:Eio.Switch.t -> env:Eio_unix.Stdenv.base -> unit
(** Start the article metadata daemon. Runs every 5 minutes. *)

val stop : unit -> unit
(** Signal the daemon to stop. *)
