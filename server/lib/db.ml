open Lwt.Syntax

(* Database connection pool *)
let pool_ref : (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt_unix.Pool.t option ref = ref None

let get_pool () =
  match !pool_ref with
  | Some pool -> pool
  | None -> failwith "Database not initialized"

(* Initialize database connection *)
let init db_path =
  let uri = Uri.of_string ("sqlite3://" ^ db_path) in
  let* pool_result = Caqti_lwt_unix.connect_pool ~max_size:10 uri in
  match pool_result with
  | Error err -> 
    Lwt.fail_with (Format.asprintf "Database connection error: %a" Caqti_error.pp err)
  | Ok pool ->
    pool_ref := Some pool;
    Lwt.return_unit

module Person = struct
  (* Query definitions *)
  let create_table_query =
    Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit)
      {|
        CREATE TABLE IF NOT EXISTS persons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      |}

  let insert_query =
    Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
      "INSERT INTO persons (name) VALUES (?) RETURNING id"

  let get_query =
    Caqti_request.Infix.(Caqti_type.int ->? Caqti_type.(t2 int string))
      "SELECT id, name FROM persons WHERE id = ?"

  let list_query =
    Caqti_request.Infix.(Caqti_type.(t2 int int) ->* Caqti_type.(t2 int string))
      "SELECT id, name FROM persons ORDER BY id LIMIT ? OFFSET ?"

  let count_query =
    Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
      "SELECT COUNT(*) FROM persons"

  let update_query =
    Caqti_request.Infix.(Caqti_type.(t2 string int) ->. Caqti_type.unit)
      "UPDATE persons SET name = ? WHERE id = ?"

  let delete_query =
    Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
      "DELETE FROM persons WHERE id = ?"

  let exists_query =
    Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
      "SELECT COUNT(*) FROM persons WHERE id = ?"

  let init_table () =
    let pool = get_pool () in
    let* result = Caqti_lwt_unix.Pool.use (fun (module Db : Caqti_lwt.CONNECTION) ->
      Db.exec create_table_query ()
    ) pool in
    match result with
    | Error err ->
      Lwt.fail_with (Format.asprintf "Table creation error: %a" Caqti_error.pp err)
    | Ok () -> Lwt.return_unit

  let create ~name =
    let pool = get_pool () in
    let* result = Caqti_lwt_unix.Pool.use (fun (module Db : Caqti_lwt.CONNECTION) ->
      Db.find insert_query name
    ) pool in
    match result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok id -> Lwt.return_ok { Person.id; name }

  let get ~id =
    let pool = get_pool () in
    let* result = Caqti_lwt_unix.Pool.use (fun (module Db : Caqti_lwt.CONNECTION) ->
      Db.find_opt get_query id
    ) pool in
    match result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok None -> Lwt.return_ok None
    | Ok (Some (id, name)) -> Lwt.return_ok (Some { Person.id; name })

  let list ~page ~per_page =
    let pool = get_pool () in
    let offset = (page - 1) * per_page in
    let* count_result = Caqti_lwt_unix.Pool.use (fun (module Db : Caqti_lwt.CONNECTION) ->
      Db.find count_query ()
    ) pool in
    match count_result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok total ->
      let* list_result = Caqti_lwt_unix.Pool.use (fun (module Db : Caqti_lwt.CONNECTION) ->
        Db.collect_list list_query (per_page, offset)
      ) pool in
      match list_result with
      | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
      | Ok rows ->
        let persons = List.map (fun (id, name) -> { Person.id; name }) rows in
        let total_pages = (total + per_page - 1) / per_page in
        Lwt.return_ok { Person.data = persons; page; per_page; total; total_pages }

  let update ~id ~name =
    let pool = get_pool () in
    let* exists_result = Caqti_lwt_unix.Pool.use (fun (module Db : Caqti_lwt.CONNECTION) ->
      Db.find exists_query id
    ) pool in
    match exists_result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok 0 -> Lwt.return_ok None
    | Ok _ ->
      let* update_result = Caqti_lwt_unix.Pool.use (fun (module Db : Caqti_lwt.CONNECTION) ->
        Db.exec update_query (name, id)
      ) pool in
      match update_result with
      | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
      | Ok () -> Lwt.return_ok (Some { Person.id; name })

  let delete ~id =
    let pool = get_pool () in
    let* exists_result = Caqti_lwt_unix.Pool.use (fun (module Db : Caqti_lwt.CONNECTION) ->
      Db.find exists_query id
    ) pool in
    match exists_result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok 0 -> Lwt.return_ok false
    | Ok _ ->
      let* delete_result = Caqti_lwt_unix.Pool.use (fun (module Db : Caqti_lwt.CONNECTION) ->
        Db.exec delete_query id
      ) pool in
      match delete_result with
      | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
      | Ok () -> Lwt.return_ok true
end
