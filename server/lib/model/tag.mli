type t

val id : t -> int
val name : t -> string
val create : id:int -> name:string -> t
val to_json : t -> Yojson.Safe.t
val of_json : Yojson.Safe.t -> t
val yojson_of_t : t -> Yojson.Safe.t
val t_of_yojson : Yojson.Safe.t -> t
val list_to_json : t list -> Yojson.Safe.t
val paginated_to_json : t Shared.Paginated.t -> Yojson.Safe.t
val error_to_json : string -> Yojson.Safe.t
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
