let caqti_error_to_string err = Format.asprintf "%a" Caqti_error.pp err

(* Database connection pool *)
let pool_ref : (Caqti_eio.connection, Caqti_error.t) Caqti_eio.Pool.t option ref
    =
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
      method net =
        (Eio.Stdenv.net stdenv :> [ `Generic ] Eio.Net.ty Eio.Resource.t)

      method clock = Eio.Stdenv.clock stdenv
      method mono_clock = Eio.Stdenv.mono_clock stdenv
    end
  in
  match Caqti_eio_unix.connect_pool ~sw ~stdenv:caqti_stdenv uri with
  | Error err ->
      failwith
        (Format.asprintf "Database connection error: %a" Caqti_error.pp err)
  | Ok pool -> pool_ref := Some pool

(* Apply database schema from embedded SQL *)
let apply_schema () =
  let pool = get () in
  let schema = Schema_sql.content in
  (* Split schema into individual statements and execute each *)
  let statements =
    String.split_on_char ';' schema
    |> List.map String.trim
    |> List.filter (fun s -> String.length s > 0)
  in
  let exec_statement stmt =
    let query =
      Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit) stmt
    in
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.exec query ())
      pool
  in
  let rec apply = function
    | [] -> ()
    | stmt :: rest -> (
        match exec_statement stmt with
        | Error err ->
            failwith
              (Format.asprintf "Schema application error: %a\nStatement: %s"
                 Caqti_error.pp err stmt)
        | Ok () -> apply rest)
  in
  apply statements
