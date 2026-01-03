(** Scheduled RSS/Atom feed synchronization. *)

val process_feed :
  sw:Eio.Switch.t -> env:Eio_unix.Stdenv.base -> Model.Rss_feed.t -> unit
(** Process a single feed immediately. *)

val start : sw:Eio.Switch.t -> env:Eio_unix.Stdenv.base -> unit
(** Start the feed sync daemon. Runs every hour. *)

val stop : unit -> unit
(** Signal the daemon to stop. *)
