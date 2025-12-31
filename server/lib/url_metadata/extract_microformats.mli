type h_card = {
  name : string option;
  url : string option;
  photo : string option;
  email : string option;
  note : string option;
  locality : string option;
  country : string option;
}

type h_entry = {
  name : string option;
  summary : string option;
  published : string option;
  updated : string option;
  author : h_card option;
  categories : string list;
}

type t = { cards : h_card list; entries : h_entry list; rel_me : string list }

val empty_card : h_card
val empty_entry : h_entry
val empty : t
val extract : base_url:Uri.t -> Soup.soup Soup.node -> t
val pp_h_card : Format.formatter -> h_card -> unit
val equal_h_card : h_card -> h_card -> bool
val pp_h_entry : Format.formatter -> h_entry -> unit
val equal_h_entry : h_entry -> h_entry -> bool
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
