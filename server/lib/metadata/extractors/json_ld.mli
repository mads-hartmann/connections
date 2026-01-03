type person = {
  name : string option;
  url : string option;
  image : string option;
  email : string option;
  job_title : string option;
  same_as : string list;
}

type article = {
  headline : string option;
  author : person option;
  date_published : string option;
  date_modified : string option;
  description : string option;
  image : string option;
}

type extracted = {
  persons : person list;
  articles : article list;
  raw : Yojson.Safe.t list;
}

val empty_person : person
val empty_article : article
val empty : extracted
val extract : Soup.soup Soup.node -> extracted
val pp_person : Format.formatter -> person -> unit
val equal_person : person -> person -> bool
val pp_article : Format.formatter -> article -> unit
val equal_article : article -> article -> bool
val pp : Format.formatter -> extracted -> unit
val equal : extracted -> extracted -> bool
