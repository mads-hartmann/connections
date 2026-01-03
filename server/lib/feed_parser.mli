(** RSS and Atom feed parsing utilities. *)

type parsed_feed = Rss2 of Syndic.Rss2.channel | Atom of Syndic.Atom.feed
type metadata = { author : string option; title : string option }

val parse : string -> (parsed_feed, string) result
(** Parse feed content as RSS2 or Atom. *)

val extract_metadata : parsed_feed -> metadata
(** Extract author and title from a parsed feed. *)

val fetch_metadata :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  string ->
  (metadata, string) result
(** Fetch a feed URL and extract its metadata. *)
