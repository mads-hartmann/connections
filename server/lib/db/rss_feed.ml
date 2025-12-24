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
  let open Result.Syntax in
  let pool = Pool.get () in
  let* id =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.find insert_query (person_id, url, title))
      pool
  in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
    pool
  |> Result.map (Option.map tuple_to_feed)

(* GET *)
let get ~id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
    pool
  |> Result.map (Option.map tuple_to_feed)

(* LIST with pagination *)
let list_by_person ~person_id ~page ~per_page =
  let open Result.Syntax in
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let* total =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.find count_by_person_query person_id)
      pool
  in
  let+ rows =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.collect_list list_by_person_query (person_id, per_page, offset))
      pool
  in
  let data = List.map tuple_to_feed rows in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total

(* UPDATE - handles partial updates *)
let update ~id ~url ~title =
  let open Result.Syntax in
  let pool = Pool.get () in
  let* exists =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find exists_query id)
      pool
  in
  match exists with
  | 0 -> Ok None
  | _ -> (
      let* current_feed_opt = get ~id in
      match current_feed_opt with
      | None -> Ok None
      | Some current_feed ->
          let new_url = Option.value url ~default:current_feed.url in
          let new_title =
            match title with Some _ -> title | None -> current_feed.title
          in
          let+ () =
            Caqti_eio.Pool.use
              (fun (module Db : Caqti_eio.CONNECTION) ->
                Db.exec update_query (new_url, new_title, id))
              pool
          in
          Some { current_feed with url = new_url; title = new_title })

(* DELETE *)
let delete ~id =
  let open Result.Syntax in
  let pool = Pool.get () in
  let* exists =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find exists_query id)
      pool
  in
  match exists with
  | 0 -> Ok false
  | _ ->
      let+ () =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) -> Db.exec delete_query id)
          pool
      in
      true

(* LIST ALL - no pagination, for scheduler *)
let list_all () =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.collect_list list_all_query ())
    pool
  |> Result.map (List.map tuple_to_feed)

(* LIST ALL with pagination *)
let list_all_paginated ~page ~per_page =
  let open Result.Syntax in
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let* total =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find count_all_query ())
      pool
  in
  let+ rows =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.collect_list list_all_paginated_query (per_page, offset))
      pool
  in
  let data = List.map tuple_to_feed rows in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total

(* UPDATE LAST FETCHED timestamp *)
let update_last_fetched ~id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec update_last_fetched_query id)
    pool
