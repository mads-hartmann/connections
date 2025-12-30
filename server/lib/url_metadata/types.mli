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

module Author : sig
  type t = {
    name : string option;
    url : string option;
    email : string option;
    photo : string option;
    bio : string option;
    location : string option;
    social_profiles : string list;
    classified_profiles : Classified_profile.t list;
  }

  val empty : t
  val is_empty : t -> bool
  val merge : t -> t -> t
  val pp : Format.formatter -> t -> unit
  val equal : t -> t -> bool
end

module Content : sig
  type t = {
    title : string option;
    description : string option;
    published_at : string option;
    modified_at : string option;
    author : Author.t option;
    image : string option;
    tags : string list;
    content_type : string option;
  }

  val empty : t
  val pp : Format.formatter -> t -> unit
  val equal : t -> t -> bool
end

module Site : sig
  type t = {
    name : string option;
    canonical_url : string option;
    favicon : string option;
    locale : string option;
    webmention_endpoint : string option;
  }

  val empty : t
  val pp : Format.formatter -> t -> unit
  val equal : t -> t -> bool
end

type t = {
  url : string;
  feeds : Feed.t list;
  author : Author.t option;
  content : Content.t;
  site : Site.t;
  raw_json_ld : Yojson.Safe.t list;
}

val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
