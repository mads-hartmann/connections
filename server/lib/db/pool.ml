let caqti_error_to_string err = Format.asprintf "%a" Caqti_error.pp err

(* Database connection pool - stores both pool and switch *)
type pool_state = {
  pool : (Caqti_eio.connection, Caqti_error.t) Caqti_eio_unix.Pool.t;
  stdenv : Eio_unix.Stdenv.base;
}

let pool_ref : pool_state option ref = ref None

let get () =
  match !pool_ref with
  | Some state -> state.pool
  | None -> failwith "Database not initialized"

let get_env () =
  match !pool_ref with
  | Some state -> state.stdenv
  | None -> failwith "Database not initialized"

(* Initialize database connection *)
let init ~sw ~stdenv db_path =
  let uri = Uri.of_string ("sqlite3:" ^ db_path) in
  match Caqti_eio_unix.connect_pool ~sw ~stdenv uri with
  | Error err ->
      failwith
        (Format.asprintf "Database connection error: %a" Caqti_error.pp err)
  | Ok pool -> pool_ref := Some { pool; stdenv }
