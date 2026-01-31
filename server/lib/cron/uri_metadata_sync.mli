val fetch_for_uri :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  Model.Uri_entry.t ->
  (Model.Uri_entry.t option, Caqti_error.t) result

val start : sw:Eio.Switch.t -> env:Eio_unix.Stdenv.base -> unit
val stop : unit -> unit
