type t = {
  title : string option;
  description : string option;
  author : string option;
  canonical : string option;
  favicon : string option;
  webmention : string option;
}

val empty : t
val extract : base_url:Uri.t -> Soup.soup Soup.node -> t
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
