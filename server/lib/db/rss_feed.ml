(* Row type definitions *)
let rss_feed_row_type =
  Caqti_type.(t6 int int string (option string) string (option string))

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
  Caqti_request.Infix.(Caqti_type.int ->? rss_feed_row_type)
    "SELECT id, person_id, url, title, created_at, last_fetched_at FROM \
     rss_feeds WHERE id = ?"

let list_by_person_query =
  Caqti_request.Infix.(Caqti_type.(t3 int int int) ->* rss_feed_row_type)
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
  Caqti_request.Infix.(Caqti_type.unit ->* rss_feed_row_type)
    "SELECT id, person_id, url, title, created_at, last_fetched_at FROM \
     rss_feeds"

let list_all_paginated_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* rss_feed_row_type)
    "SELECT id, person_id, url, title, created_at, last_fetched_at FROM \
     rss_feeds ORDER BY created_at DESC LIMIT ? OFFSET ?"

let count_all_query =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    "SELECT COUNT(*) FROM rss_feeds"

let update_last_fetched_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "UPDATE rss_feeds SET last_fetched_at = datetime('now') WHERE id = ?"

(* Helper to convert DB tuple to Model.Rss_feed.t *)
let tuple_to_feed (id, person_id, url, title, created_at, last_fetched_at) =
  { Model.Rss_feed.id; person_id; url; title; created_at; last_fetched_at }

(* Initialize table *)
let init_table () =
  let pool = Pool.get () in
  let result =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        match Db.exec enable_foreign_keys_query () with
        | Error _ as e -> e
        | Ok () -> Db.exec create_table_query ())
      pool
  in
  match result with
  | Error err ->
      failwith
        (Format.asprintf "RssFeed table creation error: %a" Caqti_error.pp err)
  | Ok () -> ()

(* CREATE *)
let create ~person_id ~url ~title =
  let pool = Pool.get () in
  let result =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.find insert_query (person_id, url, title))
      pool
  in
  match result with
  | Error err ->
      let err_msg = Pool.caqti_error_to_string err in
      Error err_msg
  | Ok id -> (
      (* Fetch the complete feed to get timestamps *)
      let get_result =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
          pool
      in
      match get_result with
      | Error err -> Error (Pool.caqti_error_to_string err)
      | Ok None -> Error "Failed to retrieve created feed"
      | Ok (Some tuple) -> Ok (tuple_to_feed tuple))

(* GET *)
let get ~id =
  let pool = Pool.get () in
  let result =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
      pool
  in
  match result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok None -> Ok None
  | Ok (Some tuple) -> Ok (Some (tuple_to_feed tuple))

(* LIST with pagination *)
let list_by_person ~person_id ~page ~per_page =
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let count_result =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.find count_by_person_query person_id)
      pool
  in
  match count_result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok total -> (
      let list_result =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.collect_list list_by_person_query (person_id, per_page, offset))
          pool
      in
      match list_result with
      | Error err -> Error (Pool.caqti_error_to_string err)
      | Ok rows ->
          let data = List.map tuple_to_feed rows in
          Ok (Model.Shared.Paginated.make ~data ~page ~per_page ~total))

(* UPDATE - handles partial updates *)
let update ~id ~url ~title =
  let pool = Pool.get () in
  let exists_result =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find exists_query id)
      pool
  in
  match exists_result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok 0 -> Ok None
  | Ok _ -> (
      (* Get current feed to merge with updates *)
      let get_result = get ~id in
      match get_result with
      | Error err -> Error err
      | Ok None -> Ok None
      | Ok (Some current_feed) -> (
          let new_url = Option.value url ~default:current_feed.url in
          let new_title =
            match title with Some _ -> title | None -> current_feed.title
          in
          let update_result =
            Caqti_eio.Pool.use
              (fun (module Db : Caqti_eio.CONNECTION) ->
                Db.exec update_query (new_url, new_title, id))
              pool
          in
          match update_result with
          | Error err ->
              let err_msg = Pool.caqti_error_to_string err in
              Error err_msg
          | Ok () ->
              Ok (Some { current_feed with url = new_url; title = new_title })))

(* DELETE *)
let delete ~id =
  let pool = Pool.get () in
  let exists_result =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find exists_query id)
      pool
  in
  match exists_result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok 0 -> Ok false
  | Ok _ -> (
      let delete_result =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) -> Db.exec delete_query id)
          pool
      in
      match delete_result with
      | Error err -> Error (Pool.caqti_error_to_string err)
      | Ok () -> Ok true)

(* LIST ALL - no pagination, for scheduler *)
let list_all () =
  let pool = Pool.get () in
  let result =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.collect_list list_all_query ())
      pool
  in
  match result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok rows -> Ok (List.map tuple_to_feed rows)

(* LIST ALL with pagination *)
let list_all_paginated ~page ~per_page =
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let count_result =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find count_all_query ())
      pool
  in
  match count_result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok total -> (
      let list_result =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.collect_list list_all_paginated_query (per_page, offset))
          pool
      in
      match list_result with
      | Error err -> Error (Pool.caqti_error_to_string err)
      | Ok rows ->
          let data = List.map tuple_to_feed rows in
          Ok (Model.Shared.Paginated.make ~data ~page ~per_page ~total))

(* UPDATE LAST FETCHED timestamp *)
let update_last_fetched ~id =
  let pool = Pool.get () in
  let result =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.exec update_last_fetched_query id)
      pool
  in
  match result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok () -> Ok ()
