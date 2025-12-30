type t =
  | Bluesky
  | Email
  | GitHub
  | LinkedIn
  | Mastodon
  | Website
  | X
  | YouTube
  | Other

val id : t -> int
val name : t -> string
val of_id : int -> t option
val all : t list
val to_json_with_id : t -> Yojson.Safe.t
val all_to_json : unit -> Yojson.Safe.t
val yojson_of_t : t -> Yojson.Safe.t
val t_of_yojson : Yojson.Safe.t -> t
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
