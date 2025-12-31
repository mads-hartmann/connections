type error_response = { error : string }

val yojson_of_error_response : error_response -> Yojson.Safe.t
val error_to_json : string -> Yojson.Safe.t

module Paginated : sig
  type 'a t = {
    data : 'a list;
    page : int;
    per_page : int;
    total : int;
    total_pages : int;
  }

  val to_json : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t
  val make : data:'a list -> page:int -> per_page:int -> total:int -> 'a t
end
