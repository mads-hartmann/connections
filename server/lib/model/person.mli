type t

val id : t -> int
val name : t -> string
val tags : t -> Tag.t list
val metadata : t -> Person_metadata.t list
val create :
  id:int -> name:string -> tags:Tag.t list -> metadata:Person_metadata.t list -> t
val with_metadata : t -> Person_metadata.t list -> t
val to_json : t -> Yojson.Safe.t
val paginated_to_json : t Shared.Paginated.t -> Yojson.Safe.t
val error_to_json : string -> Yojson.Safe.t
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool

type t_with_counts

val id_with_counts : t_with_counts -> int
val name_with_counts : t_with_counts -> string
val tags_with_counts : t_with_counts -> Tag.t list
val feed_count : t_with_counts -> int
val article_count : t_with_counts -> int
val metadata_with_counts : t_with_counts -> Person_metadata.t list
val create_with_counts :
  id:int ->
  name:string ->
  tags:Tag.t list ->
  feed_count:int ->
  article_count:int ->
  metadata:Person_metadata.t list ->
  t_with_counts
val with_metadata_counts : t_with_counts -> Person_metadata.t list -> t_with_counts
val to_json_with_counts : t_with_counts -> Yojson.Safe.t
val paginated_with_counts_to_json : t_with_counts Shared.Paginated.t -> Yojson.Safe.t
val pp_with_counts : Format.formatter -> t_with_counts -> unit
val equal_with_counts : t_with_counts -> t_with_counts -> bool
