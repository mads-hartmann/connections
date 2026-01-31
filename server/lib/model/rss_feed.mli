type t

val id : t -> int
val connection_id : t -> int
val url : t -> string
val title : t -> string option
val created_at : t -> string
val last_fetched_at : t -> string option
val tags : t -> Tag.t list

val create :
  id:int ->
  connection_id:int ->
  url:string ->
  title:string option ->
  created_at:string ->
  last_fetched_at:string option ->
  tags:Tag.t list ->
  t

val to_json : t -> Yojson.Safe.t
val of_json : Yojson.Safe.t -> t
val yojson_of_t : t -> Yojson.Safe.t
val t_of_yojson : Yojson.Safe.t -> t
val paginated_to_json : t Shared.Paginated.t -> Yojson.Safe.t
val error_to_json : string -> Yojson.Safe.t
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
