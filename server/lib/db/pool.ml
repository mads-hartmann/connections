let caqti_error_to_string err = Format.asprintf "%a" Caqti_error.pp err

(* Database connection pool *)
let pool_ref :
    (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt_unix.Pool.t option ref =
  ref None

let get () =
  match !pool_ref with
  | Some pool -> pool
  | None -> failwith "Database not initialized"

(* Initialize database connection *)
let init db_path =
  let uri = Uri.of_string ("sqlite3:" ^ db_path) in
  match Caqti_lwt_unix.connect_pool uri with
  | Error err ->
      Lwt.fail_with
        (Format.asprintf "Database connection error: %a" Caqti_error.pp err)
  | Ok pool ->
      pool_ref := Some pool;
      Lwt.return_unit
