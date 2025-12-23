let caqti_error_to_string err = Format.asprintf "%a" Caqti_error.pp err

(* Database connection pool *)
let pool_ref : (Caqti_eio.connection, Caqti_error.t) Caqti_eio.Pool.t option ref =
  ref None

let get () =
  match !pool_ref with
  | Some pool -> pool
  | None -> failwith "Database not initialized"

(* Initialize database connection *)
let init ~sw ~(stdenv : Eio_unix.Stdenv.base) db_path =
  let uri = Uri.of_string ("sqlite3:" ^ db_path) in
  let caqti_stdenv : Caqti_eio.stdenv =
    object
      method net = (Eio.Stdenv.net stdenv :> [`Generic] Eio.Net.ty Eio.Resource.t)
      method clock = Eio.Stdenv.clock stdenv
      method mono_clock = Eio.Stdenv.mono_clock stdenv
    end
  in
  match Caqti_eio_unix.connect_pool ~sw ~stdenv:caqti_stdenv uri with
  | Error err ->
      failwith
        (Format.asprintf "Database connection error: %a" Caqti_error.pp err)
  | Ok pool -> pool_ref := Some pool
