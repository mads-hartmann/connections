type t = {
  card_type : string option;
  site : string option;
  creator : string option;
  title : string option;
  description : string option;
  image : string option;
}

val empty : t
val extract : Soup.soup Soup.node -> t
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
