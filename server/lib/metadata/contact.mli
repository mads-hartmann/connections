(** Contact metadata extraction from personal/site homepages.

    Extracts information about a person from their homepage using Microformats
    h-card, JSON-LD Person, rel-me links, and RSS/Atom feeds. *)

module Feed : sig
  type format = Rss | Atom | Json_feed
  type t = { url : string; title : string option; format : format }

  val pp_format : Format.formatter -> format -> unit
  val equal_format : format -> format -> bool
  val pp : Format.formatter -> t -> unit
  val equal : t -> t -> bool
end

module Classified_profile : sig
  type t = { url : string; field_type : Model.Metadata_field_type.t }

  val pp : Format.formatter -> t -> unit
  val equal : t -> t -> bool
end

type t = {
  name : string option;
  url : string option;
  email : string option;
  photo : string option;
  bio : string option;
  location : string option;
  feeds : Feed.t list;
  social_profiles : Classified_profile.t list;
}

val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
val to_json : t -> Yojson.Safe.t

val extract : url:string -> html:string -> t
(** Extract contact metadata from HTML content. *)

val fetch :
  sw:Eio.Switch.t -> env:Eio_unix.Stdenv.base -> string -> (t, string) result
(** Fetch a URL and extract contact metadata. *)
