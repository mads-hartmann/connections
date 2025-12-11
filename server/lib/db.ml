open Lwt.Syntax

(* Database connection pool *)
let pool_ref :
    (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt_unix.Pool.t option ref =
  ref None

let get_pool () =
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

  let list_filtered_query =
    Caqti_request.Infix.(
      Caqti_type.(t3 string int int) ->* Caqti_type.(t2 int string))
      "SELECT id, name FROM persons WHERE name LIKE ? ORDER BY name DESC LIMIT \
       ? OFFSET ?"

  let count_filtered_query =
    Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
      "SELECT COUNT(*) FROM persons WHERE name LIKE ?"

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
    let* result =
      Caqti_lwt_unix.Pool.use
        (fun (module Db : Caqti_lwt.CONNECTION) ->
          Db.exec create_table_query ())
        pool
    in
    match result with
    | Error err ->
        Lwt.fail_with
          (Format.asprintf "Table creation error: %a" Caqti_error.pp err)
    | Ok () -> Lwt.return_unit

  let create ~name =
    let pool = get_pool () in
    let* result =
      Caqti_lwt_unix.Pool.use
        (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find insert_query name)
        pool
    in
    match result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok id -> Lwt.return_ok { Person.id; name }

  let get ~id =
    let pool = get_pool () in
    let* result =
      Caqti_lwt_unix.Pool.use
        (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find_opt get_query id)
        pool
    in
    match result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok None -> Lwt.return_ok None
    | Ok (Some (id, name)) -> Lwt.return_ok (Some { Person.id; name })

  let list ~page ~per_page ?query () =
    let pool = get_pool () in
    let offset = (page - 1) * per_page in
    let* count_result =
      match query with
      | None ->
          Caqti_lwt_unix.Pool.use
            (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find count_query ())
            pool
      | Some q ->
          let pattern = "%" ^ q ^ "%" in
          Caqti_lwt_unix.Pool.use
            (fun (module Db : Caqti_lwt.CONNECTION) ->
              Db.find count_filtered_query pattern)
            pool
    in
    match count_result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok total -> (
        let* list_result =
          match query with
          | None ->
              Caqti_lwt_unix.Pool.use
                (fun (module Db : Caqti_lwt.CONNECTION) ->
                  Db.collect_list list_query (per_page, offset))
                pool
          | Some q ->
              let pattern = "%" ^ q ^ "%" in
              Caqti_lwt_unix.Pool.use
                (fun (module Db : Caqti_lwt.CONNECTION) ->
                  Db.collect_list list_filtered_query (pattern, per_page, offset))
                pool
        in
        match list_result with
        | Error err ->
            Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
        | Ok rows ->
            let persons =
              List.map (fun (id, name) -> { Person.id; name }) rows
            in
            let total_pages = (total + per_page - 1) / per_page in
            Lwt.return_ok
              { Person.data = persons; page; per_page; total; total_pages })

  let update ~id ~name =
    let pool = get_pool () in
    let* exists_result =
      Caqti_lwt_unix.Pool.use
        (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find exists_query id)
        pool
    in
    match exists_result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok 0 -> Lwt.return_ok None
    | Ok _ -> (
        let* update_result =
          Caqti_lwt_unix.Pool.use
            (fun (module Db : Caqti_lwt.CONNECTION) ->
              Db.exec update_query (name, id))
            pool
        in
        match update_result with
        | Error err ->
            Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
        | Ok () -> Lwt.return_ok (Some { Person.id; name }))

  let delete ~id =
    let pool = get_pool () in
    let* exists_result =
      Caqti_lwt_unix.Pool.use
        (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find exists_query id)
        pool
    in
    match exists_result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok 0 -> Lwt.return_ok false
    | Ok _ -> (
        let* delete_result =
          Caqti_lwt_unix.Pool.use
            (fun (module Db : Caqti_lwt.CONNECTION) -> Db.exec delete_query id)
            pool
        in
        match delete_result with
        | Error err ->
            Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
        | Ok () -> Lwt.return_ok true)
end

module RssFeed = struct
  (* Query definitions *)
  let create_table_query =
    Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit)
      {|
        CREATE TABLE IF NOT EXISTS rss_feeds (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          person_id INTEGER NOT NULL,
          url TEXT NOT NULL,
          title TEXT,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          last_fetched_at TEXT,
          FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE RESTRICT,
          UNIQUE(person_id, url)
        )
      |}

  let enable_foreign_keys_query =
    Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit)
      "PRAGMA foreign_keys = ON"

  let insert_query =
    Caqti_request.Infix.(
      Caqti_type.(t3 int string (option string)) ->! Caqti_type.int)
      "INSERT INTO rss_feeds (person_id, url, title) VALUES (?, ?, ?) \
       RETURNING id"

  let get_query =
    Caqti_request.Infix.(
      Caqti_type.int
      ->? Caqti_type.(t6 int int string (option string) string (option string)))
      "SELECT id, person_id, url, title, created_at, last_fetched_at FROM \
       rss_feeds WHERE id = ?"

  let list_by_person_query =
    Caqti_request.Infix.(
      Caqti_type.(t3 int int int)
      ->* Caqti_type.(t6 int int string (option string) string (option string)))
      "SELECT id, person_id, url, title, created_at, last_fetched_at FROM \
       rss_feeds WHERE person_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?"

  let count_by_person_query =
    Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
      "SELECT COUNT(*) FROM rss_feeds WHERE person_id = ?"

  let update_query =
    Caqti_request.Infix.(
      Caqti_type.(t3 string (option string) int) ->. Caqti_type.unit)
      "UPDATE rss_feeds SET url = ?, title = ? WHERE id = ?"

  let delete_query =
    Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
      "DELETE FROM rss_feeds WHERE id = ?"

  let exists_query =
    Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
      "SELECT COUNT(*) FROM rss_feeds WHERE id = ?"

  (* Helper to convert DB tuple to Rss_feed.t *)
  let tuple_to_feed (id, person_id, url, title, created_at, last_fetched_at) =
    { Rss_feed.id; person_id; url; title; created_at; last_fetched_at }

  (* Initialize table *)
  let init_table () =
    let pool = get_pool () in
    let* result =
      Caqti_lwt_unix.Pool.use
        (fun (module Db : Caqti_lwt.CONNECTION) ->
          let* _ = Db.exec enable_foreign_keys_query () in
          Db.exec create_table_query ())
        pool
    in
    match result with
    | Error err ->
        Lwt.fail_with
          (Format.asprintf "RssFeed table creation error: %a" Caqti_error.pp err)
    | Ok () -> Lwt.return_unit

  (* CREATE *)
  let create ~person_id ~url ~title =
    let pool = get_pool () in
    let* result =
      Caqti_lwt_unix.Pool.use
        (fun (module Db : Caqti_lwt.CONNECTION) ->
          Db.find insert_query (person_id, url, title))
        pool
    in
    match result with
    | Error err ->
        let err_msg = Format.asprintf "%a" Caqti_error.pp err in
        Lwt.return_error err_msg
    | Ok id -> (
        (* Fetch the complete feed to get timestamps *)
        let* get_result =
          Caqti_lwt_unix.Pool.use
            (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find_opt get_query id)
            pool
        in
        match get_result with
        | Error err ->
            Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
        | Ok None -> Lwt.return_error "Failed to retrieve created feed"
        | Ok (Some tuple) -> Lwt.return_ok (tuple_to_feed tuple))

  (* GET *)
  let get ~id =
    let pool = get_pool () in
    let* result =
      Caqti_lwt_unix.Pool.use
        (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find_opt get_query id)
        pool
    in
    match result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok None -> Lwt.return_ok None
    | Ok (Some tuple) -> Lwt.return_ok (Some (tuple_to_feed tuple))

  (* LIST with pagination *)
  let list_by_person ~person_id ~page ~per_page =
    let pool = get_pool () in
    let offset = (page - 1) * per_page in
    let* count_result =
      Caqti_lwt_unix.Pool.use
        (fun (module Db : Caqti_lwt.CONNECTION) ->
          Db.find count_by_person_query person_id)
        pool
    in
    match count_result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok total -> (
        let* list_result =
          Caqti_lwt_unix.Pool.use
            (fun (module Db : Caqti_lwt.CONNECTION) ->
              Db.collect_list list_by_person_query (person_id, per_page, offset))
            pool
        in
        match list_result with
        | Error err ->
            Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
        | Ok rows ->
            let feeds = List.map tuple_to_feed rows in
            let total_pages = (total + per_page - 1) / per_page in
            Lwt.return_ok
              { Rss_feed.data = feeds; page; per_page; total; total_pages })

  (* UPDATE - handles partial updates *)
  let update ~id ~url ~title =
    let pool = get_pool () in
    let* exists_result =
      Caqti_lwt_unix.Pool.use
        (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find exists_query id)
        pool
    in
    match exists_result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok 0 -> Lwt.return_ok None
    | Ok _ -> (
        (* Get current feed to merge with updates *)
        let* get_result = get ~id in
        match get_result with
        | Error err -> Lwt.return_error err
        | Ok None -> Lwt.return_ok None
        | Ok (Some current_feed) -> (
            let new_url = Option.value url ~default:current_feed.url in
            let new_title =
              match title with Some _ -> title | None -> current_feed.title
            in
            let* update_result =
              Caqti_lwt_unix.Pool.use
                (fun (module Db : Caqti_lwt.CONNECTION) ->
                  Db.exec update_query (new_url, new_title, id))
                pool
            in
            match update_result with
            | Error err ->
                let err_msg = Format.asprintf "%a" Caqti_error.pp err in
                Lwt.return_error err_msg
            | Ok () ->
                Lwt.return_ok
                  (Some { current_feed with url = new_url; title = new_title }))
        )

  (* DELETE *)
  let delete ~id =
    let pool = get_pool () in
    let* exists_result =
      Caqti_lwt_unix.Pool.use
        (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find exists_query id)
        pool
    in
    match exists_result with
    | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
    | Ok 0 -> Lwt.return_ok false
    | Ok _ -> (
        let* delete_result =
          Caqti_lwt_unix.Pool.use
            (fun (module Db : Caqti_lwt.CONNECTION) -> Db.exec delete_query id)
            pool
        in
        match delete_result with
        | Error err ->
            Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
        | Ok () -> Lwt.return_ok true)
end
