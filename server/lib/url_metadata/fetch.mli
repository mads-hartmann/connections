(** HTTP fetching with redirect handling *)

val fetch_html :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  string ->
  (string, string) result
(** Fetch HTML content from a URL, following redirects up to 10 times. *)
