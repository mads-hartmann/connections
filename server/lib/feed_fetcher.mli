type parsed_feed = Rss2 of Syndic.Rss2.channel | Atom of Syndic.Atom.feed
type feed_metadata = { author : string option; title : string option }

val parse_feed : string -> (parsed_feed, string) result
val extract_metadata : parsed_feed -> feed_metadata

val fetch_feed_metadata :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  string ->
  (feed_metadata, string) result

val process_feed :
  sw:Eio.Switch.t -> env:Eio_unix.Stdenv.base -> Model.Rss_feed.t -> unit

val fetch_all_feeds :
  sw:Eio.Switch.t -> env:Eio_unix.Stdenv.base -> unit -> unit
