open Lwt.Syntax

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
    "INSERT INTO rss_feeds (person_id, url, title) VALUES (?, ?, ?) RETURNING \
     id"

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

let list_all_query =
  Caqti_request.Infix.(
    Caqti_type.unit
    ->* Caqti_type.(t6 int int string (option string) string (option string)))
    "SELECT id, person_id, url, title, created_at, last_fetched_at FROM \
     rss_feeds"

let update_last_fetched_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "UPDATE rss_feeds SET last_fetched_at = datetime('now') WHERE id = ?"

(* Helper to convert DB tuple to Model.Rss_feed.t *)
let tuple_to_feed (id, person_id, url, title, created_at, last_fetched_at) =
  { Model.Rss_feed.id; person_id; url; title; created_at; last_fetched_at }

(* Initialize table *)
let init_table () =
  let pool = Pool.get () in
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
  let pool = Pool.get () in
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
      | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
      | Ok None -> Lwt.return_error "Failed to retrieve created feed"
      | Ok (Some tuple) -> Lwt.return_ok (tuple_to_feed tuple))

(* GET *)
let get ~id =
  let pool = Pool.get () in
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
  let pool = Pool.get () in
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
      | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
      | Ok rows ->
          let feeds = List.map tuple_to_feed rows in
          let total_pages = (total + per_page - 1) / per_page in
          Lwt.return_ok
            { Model.Rss_feed.data = feeds; page; per_page; total; total_pages })

(* UPDATE - handles partial updates *)
let update ~id ~url ~title =
  let pool = Pool.get () in
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
                (Some { current_feed with url = new_url; title = new_title })))

(* DELETE *)
let delete ~id =
  let pool = Pool.get () in
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
      | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
      | Ok () -> Lwt.return_ok true)

(* LIST ALL - no pagination, for scheduler *)
let list_all () =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) ->
        Db.collect_list list_all_query ())
      pool
  in
  match result with
  | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
  | Ok rows -> Lwt.return_ok (List.map tuple_to_feed rows)

(* UPDATE LAST FETCHED timestamp *)
let update_last_fetched ~id =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) ->
        Db.exec update_last_fetched_query id)
      pool
  in
  match result with
  | Error err -> Lwt.return_error (Format.asprintf "%a" Caqti_error.pp err)
  | Ok () -> Lwt.return_ok ()
