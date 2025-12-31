val get : unit -> (Caqti_eio.connection, Caqti_error.t) Caqti_eio.Pool.t
val init : sw:Eio.Switch.t -> stdenv:Eio_unix.Stdenv.base -> string -> unit
val exec_sql : string -> unit
val apply_schema : unit -> unit
