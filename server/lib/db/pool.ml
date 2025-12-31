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

(* Execute SQL statements from a string.
   SQLite/Caqti doesn't support multi-statement execution in prepared statements,
   so we split on semicolons and execute each statement individually. *)
let exec_sql sql =
  let pool = get () in
  let statements =
    String.split_on_char ';' sql
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
              (Format.asprintf "SQL execution error: %a\nStatement: %s"
                 Caqti_error.pp err stmt)
        | Ok () -> apply rest)
  in
  apply statements

(* Apply database schema embedded at build time from schema.sql *)
let apply_schema () = exec_sql Schema_sql.content
