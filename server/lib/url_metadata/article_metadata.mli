(** Article metadata extraction from web pages.

    Extracts information about articles/content using OpenGraph,
    Twitter Cards, JSON-LD Article, and HTML meta tags. *)

type t = {
  title : string option;
  description : string option;
  image : string option;
  published_at : string option;
  modified_at : string option;
  author_name : string option;
  site_name : string option;
  canonical_url : string option;
  tags : string list;
  content_type : string option;
}

val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
val to_json : t -> Yojson.Safe.t

val extract : url:string -> html:string -> t
(** Extract article metadata from HTML content. *)

val fetch :
  sw:Eio.Switch.t -> env:Eio_unix.Stdenv.base -> string -> (t, string) result
(** Fetch a URL and extract article metadata. *)
