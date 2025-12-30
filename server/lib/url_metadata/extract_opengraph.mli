type t = {
  title : string option;
  og_type : string option;
  url : string option;
  image : string option;
  description : string option;
  site_name : string option;
  locale : string option;
  author : string option;
  published_time : string option;
  modified_time : string option;
  tags : string list;
}

val empty : t
val extract : Soup.soup Soup.node -> t
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
