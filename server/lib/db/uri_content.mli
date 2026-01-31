val get_by_uri_id : uri_id:int -> ((int * string) option, Caqti_error.t) result
val upsert : uri_id:int -> markdown:string -> (unit, Caqti_error.t) result
val delete_by_uri_id : uri_id:int -> (unit, Caqti_error.t) result
