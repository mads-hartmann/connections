type t = Blog | Video | Tweet | Book | Site | Unknown | Podcast | Paper

val to_string : t -> string
val of_string : string -> t option
val of_string_exn : string -> t
val to_id : t -> int
val of_id : int -> t option
val of_id_exn : int -> t
val all : t list
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
val yojson_of_t : t -> Yojson.Safe.t
val t_of_yojson : Yojson.Safe.t -> t
