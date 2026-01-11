type t

val id : t -> int
val feed_id : t -> int option
val person_id : t -> int option
val person_name : t -> string option
val title : t -> string option
val url : t -> string
val published_at : t -> string option
val content : t -> string option
val author : t -> string option
val image_url : t -> string option
val created_at : t -> string
val read_at : t -> string option
val read_later_at : t -> string option
val tags : t -> Tag.t list
val og_title : t -> string option
val og_description : t -> string option
val og_image : t -> string option
val og_site_name : t -> string option
val og_fetched_at : t -> string option
val og_fetch_error : t -> string option

val create :
  id:int ->
  feed_id:int option ->
  person_id:int option ->
  person_name:string option ->
  title:string option ->
  url:string ->
  published_at:string option ->
  content:string option ->
  author:string option ->
  image_url:string option ->
  created_at:string ->
  read_at:string option ->
  read_later_at:string option ->
  tags:Tag.t list ->
  og_title:string option ->
  og_description:string option ->
  og_image:string option ->
  og_site_name:string option ->
  og_fetched_at:string option ->
  og_fetch_error:string option ->
  t

val to_json : t -> Yojson.Safe.t
val of_json : Yojson.Safe.t -> t
val yojson_of_t : t -> Yojson.Safe.t
val t_of_yojson : Yojson.Safe.t -> t
val paginated_to_json : t Shared.Paginated.t -> Yojson.Safe.t
val error_to_json : string -> Yojson.Safe.t
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
