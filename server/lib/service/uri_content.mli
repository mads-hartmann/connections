module Error : sig
  type t =
    | Uri_not_found
    | Fetch_failed of string
    | Database of Caqti_error.t

  val pp : Format.formatter -> t -> unit
  val to_string : t -> string
end

val get :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  uri_id:int ->
  (string, Error.t) result

val invalidate : uri_id:int -> (unit, Error.t) result
