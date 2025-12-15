open Lwt.Syntax

(* Query definitions *)
let create_table_query =
  Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit)
    {|
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    |}

let create_junction_table_query =
  Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit)
    {|
      CREATE TABLE IF NOT EXISTS person_categories (
        person_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        PRIMARY KEY (person_id, category_id),
        FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    |}

let insert_query =
  Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
    "INSERT INTO categories (name) VALUES (?) RETURNING id"

let get_query =
  Caqti_request.Infix.(Caqti_type.int ->? Caqti_type.(t2 int string))
    "SELECT id, name FROM categories WHERE id = ?"

let get_by_name_query =
  Caqti_request.Infix.(Caqti_type.string ->? Caqti_type.(t2 int string))
    "SELECT id, name FROM categories WHERE name = ?"

let list_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* Caqti_type.(t2 int string))
    "SELECT id, name FROM categories ORDER BY name LIMIT ? OFFSET ?"

let list_all_query =
  Caqti_request.Infix.(Caqti_type.unit ->* Caqti_type.(t2 int string))
    "SELECT id, name FROM categories ORDER BY name"

let count_query =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    "SELECT COUNT(*) FROM categories"

let delete_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "DELETE FROM categories WHERE id = ?"

let exists_query =
  Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
    "SELECT COUNT(*) FROM categories WHERE id = ?"

let add_to_person_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->. Caqti_type.unit)
    "INSERT OR IGNORE INTO person_categories (person_id, category_id) VALUES \
     (?, ?)"

let remove_from_person_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->. Caqti_type.unit)
    "DELETE FROM person_categories WHERE person_id = ? AND category_id = ?"

let get_by_person_query =
  Caqti_request.Infix.(Caqti_type.int ->* Caqti_type.(t2 int string))
    "SELECT c.id, c.name FROM categories c INNER JOIN person_categories pc ON \
     c.id = pc.category_id WHERE pc.person_id = ? ORDER BY c.name"

let init_table () =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) ->
        let open Lwt_result.Syntax in
        let* () = Db.exec create_table_query () in
        Db.exec create_junction_table_query ())
      pool
  in
  match result with
  | Error err ->
      Lwt.fail_with
        (Format.asprintf "Table creation error: %a" Caqti_error.pp err)
  | Ok () -> Lwt.return_unit

let create ~name =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find insert_query name)
      pool
  in
  match result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok id -> Lwt.return_ok { Model.Category.id; name }

let get ~id =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find_opt get_query id)
      pool
  in
  match result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok None -> Lwt.return_ok None
  | Ok (Some (id, name)) -> Lwt.return_ok (Some { Model.Category.id; name })

let get_by_name ~name =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find_opt get_by_name_query name)
      pool
  in
  match result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok None -> Lwt.return_ok None
  | Ok (Some (id, name)) -> Lwt.return_ok (Some { Model.Category.id; name })

let get_or_create ~name =
  let* existing = get_by_name ~name in
  match existing with
  | Error err -> Lwt.return_error err
  | Ok (Some category) -> Lwt.return_ok category
  | Ok None -> create ~name

let list_all () =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) -> Db.collect_list list_all_query ())
      pool
  in
  match result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok rows ->
      let categories =
        List.map (fun (id, name) -> { Model.Category.id; name }) rows
      in
      Lwt.return_ok categories

let list ~page ~per_page () =
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let* count_result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find count_query ())
      pool
  in
  match count_result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok total -> (
      let* list_result =
        Caqti_lwt_unix.Pool.use
          (fun (module Db : Caqti_lwt.CONNECTION) ->
            Db.collect_list list_query (per_page, offset))
          pool
      in
      match list_result with
      | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
      | Ok rows ->
          let data =
            List.map (fun (id, name) -> { Model.Category.id; name }) rows
          in
          Lwt.return_ok (Model.Shared.Paginated.make ~data ~page ~per_page ~total))

let delete ~id =
  let pool = Pool.get () in
  let* exists_result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find exists_query id)
      pool
  in
  match exists_result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok 0 -> Lwt.return_ok false
  | Ok _ -> (
      let* delete_result =
        Caqti_lwt_unix.Pool.use
          (fun (module Db : Caqti_lwt.CONNECTION) -> Db.exec delete_query id)
          pool
      in
      match delete_result with
      | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
      | Ok () -> Lwt.return_ok true)

let add_to_person ~person_id ~category_id =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) ->
        Db.exec add_to_person_query (person_id, category_id))
      pool
  in
  match result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok () -> Lwt.return_ok ()

let remove_from_person ~person_id ~category_id =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) ->
        Db.exec remove_from_person_query (person_id, category_id))
      pool
  in
  match result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok () -> Lwt.return_ok ()

let get_by_person ~person_id =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) ->
        Db.collect_list get_by_person_query person_id)
      pool
  in
  match result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok rows ->
      let categories =
        List.map (fun (id, name) -> { Model.Category.id; name }) rows
      in
      Lwt.return_ok categories
