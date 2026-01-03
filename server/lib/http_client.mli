(** HTTP client with redirect handling. *)

val fetch :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  string ->
  (string, string) result
(** Fetch content from a URL, following redirects up to 10 times. *)
