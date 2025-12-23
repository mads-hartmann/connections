(* Query definitions *)
let create_table_query =
  Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit)
    {|
      CREATE TABLE IF NOT EXISTS articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feed_id INTEGER NOT NULL,
        title TEXT,
        url TEXT NOT NULL,
        published_at TEXT,
        content TEXT,
        author TEXT,
        image_url TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        read_at TEXT,
        FOREIGN KEY (feed_id) REFERENCES rss_feeds(id) ON DELETE CASCADE,
        UNIQUE(feed_id, url)
      )
    |}

let create_feed_index_query =
  Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit)
    "CREATE INDEX IF NOT EXISTS idx_articles_feed_id ON articles(feed_id)"

let create_read_index_query =
  Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit)
    "CREATE INDEX IF NOT EXISTS idx_articles_read_at ON articles(read_at)"

(* Article row type: 10 fields split as t2 of (t5, t5) *)
let article_row_type =
  Caqti_type.(
    t2
      (t5 int int (option string) string (option string))
      (t5 (option string) (option string) (option string) string (option string)))

(* Upsert input type: 7 fields *)
let upsert_input_type =
  Caqti_type.(
    t7 int (option string) string (option string) (option string)
      (option string) (option string))

let upsert_query =
  Caqti_request.Infix.(upsert_input_type ->. Caqti_type.unit)
    {|
      INSERT OR IGNORE INTO articles (feed_id, title, url, published_at, content, author, image_url)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    |}

let get_query =
  Caqti_request.Infix.(Caqti_type.int ->? article_row_type)
    {|
      SELECT id, feed_id, title, url, published_at, content, author, image_url, created_at, read_at
      FROM articles WHERE id = ?
    |}

let list_by_feed_query =
  Caqti_request.Infix.(Caqti_type.(t3 int int int) ->* article_row_type)
    {|
      SELECT id, feed_id, title, url, published_at, content, author, image_url, created_at, read_at
      FROM articles WHERE feed_id = ? ORDER BY published_at DESC, created_at DESC LIMIT ? OFFSET ?
    |}

let count_by_feed_query =
  Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
    "SELECT COUNT(*) FROM articles WHERE feed_id = ?"

let list_all_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* article_row_type)
    {|
      SELECT id, feed_id, title, url, published_at, content, author, image_url, created_at, read_at
      FROM articles ORDER BY published_at DESC, created_at DESC LIMIT ? OFFSET ?
    |}

let count_all_query =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    "SELECT COUNT(*) FROM articles"

let list_unread_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* article_row_type)
    {|
      SELECT id, feed_id, title, url, published_at, content, author, image_url, created_at, read_at
      FROM articles WHERE read_at IS NULL ORDER BY published_at DESC, created_at DESC LIMIT ? OFFSET ?
    |}

let count_unread_query =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    "SELECT COUNT(*) FROM articles WHERE read_at IS NULL"

let mark_read_query =
  Caqti_request.Infix.(Caqti_type.(t2 (option string) int) ->. Caqti_type.unit)
    "UPDATE articles SET read_at = ? WHERE id = ?"

let mark_all_read_query =
  Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
    "UPDATE articles SET read_at = datetime('now') WHERE feed_id = ? AND \
     read_at IS NULL RETURNING id"

let delete_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "DELETE FROM articles WHERE id = ?"

let exists_query =
  Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
    "SELECT COUNT(*) FROM articles WHERE id = ?"

(* Helper to convert DB tuple to Model.Article.t *)
let tuple_to_article
    ( (id, feed_id, title, url, published_at),
      (content, author, image_url, created_at, read_at) ) =
  {
    Model.Article.id;
    feed_id;
    title;
    url;
    published_at;
    content;
    author;
    image_url;
    created_at;
    read_at;
  }

(* Initialize table *)
let init_table () =
  let pool = Pool.get () in
  let result =
    Caqti_eio_unix.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        match Db.exec create_table_query () with
        | Error _ as e -> e
        | Ok () -> (
            match Db.exec create_feed_index_query () with
            | Error _ as e -> e
            | Ok () -> Db.exec create_read_index_query ()))
      pool
  in
  match result with
  | Error err ->
      failwith
        (Format.asprintf "Article table creation error: %a" Caqti_error.pp err)
  | Ok () -> ()

(* UPSERT - returns true if inserted, false if duplicate *)
let upsert (input : Model.Article.create_input) =
  let pool = Pool.get () in
  let {
    Model.Article.feed_id;
    title;
    url;
    published_at;
    content;
    author;
    image_url;
  } =
    input
  in
  let params =
    (feed_id, title, url, published_at, content, author, image_url)
  in
  let result =
    Caqti_eio_unix.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.exec upsert_query params)
      pool
  in
  match result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok () -> Ok ()

(* UPSERT MANY - returns count of inserted articles *)
let upsert_many (inputs : Model.Article.create_input list) =
  let pool = Pool.get () in
  let result =
    Caqti_eio_unix.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        let rec loop count = function
          | [] -> Ok count
          | input :: rest -> (
              let {
                Model.Article.feed_id;
                title;
                url;
                published_at;
                content;
                author;
                image_url;
              } =
                input
              in
              let params =
                (feed_id, title, url, published_at, content, author, image_url)
              in
              let exec_result = Db.exec upsert_query params in
              match exec_result with
              | Error err -> Error err
              | Ok () ->
                  (* SQLite changes() would tell us if row was inserted, but we approximate *)
                  loop (count + 1) rest)
        in
        loop 0 inputs)
      pool
  in
  match result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok count -> Ok count

(* GET *)
let get ~id =
  let pool = Pool.get () in
  let result =
    Caqti_eio_unix.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
      pool
  in
  match result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok None -> Ok None
  | Ok (Some tuple) -> Ok (Some (tuple_to_article tuple))

(* LIST BY FEED with pagination *)
let list_by_feed ~feed_id ~page ~per_page =
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let count_result =
    Caqti_eio_unix.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.find count_by_feed_query feed_id)
      pool
  in
  match count_result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok total -> (
      let list_result =
        Caqti_eio_unix.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.collect_list list_by_feed_query (feed_id, per_page, offset))
          pool
      in
      match list_result with
      | Error err -> Error (Pool.caqti_error_to_string err)
      | Ok rows ->
          let data = List.map tuple_to_article rows in
          Ok (Model.Shared.Paginated.make ~data ~page ~per_page ~total))

(* LIST ALL with pagination and optional unread filter *)
let list_all ~page ~per_page ~unread_only =
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let count_result =
    Caqti_eio_unix.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        if unread_only then Db.find count_unread_query ()
        else Db.find count_all_query ())
      pool
  in
  match count_result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok total -> (
      let list_result =
        Caqti_eio_unix.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            if unread_only then
              Db.collect_list list_unread_query (per_page, offset)
            else Db.collect_list list_all_query (per_page, offset))
          pool
      in
      match list_result with
      | Error err -> Error (Pool.caqti_error_to_string err)
      | Ok rows ->
          let data = List.map tuple_to_article rows in
          Ok (Model.Shared.Paginated.make ~data ~page ~per_page ~total))

(* MARK READ/UNREAD *)
let mark_read ~id ~read =
  let pool = Pool.get () in
  let exists_result =
    Caqti_eio_unix.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find exists_query id)
      pool
  in
  match exists_result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok 0 -> Ok None
  | Ok _ -> (
      let read_at =
        if read then
          (* Get current timestamp in SQLite format *)
          let now = Unix.gettimeofday () in
          let tm = Unix.gmtime now in
          Some
            (Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d"
               (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday
               tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec)
        else None
      in
      let update_result =
        Caqti_eio_unix.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.exec mark_read_query (read_at, id))
          pool
      in
      match update_result with
      | Error err -> Error (Pool.caqti_error_to_string err)
      | Ok () -> get ~id)

(* MARK ALL READ for a feed *)
let mark_all_read ~feed_id =
  let pool = Pool.get () in
  let result =
    Caqti_eio_unix.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.collect_list mark_all_read_query feed_id)
      pool
  in
  match result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok ids -> Ok (List.length ids)

(* DELETE *)
let delete ~id =
  let pool = Pool.get () in
  let exists_result =
    Caqti_eio_unix.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find exists_query id)
      pool
  in
  match exists_result with
  | Error err -> Error (Pool.caqti_error_to_string err)
  | Ok 0 -> Ok false
  | Ok _ -> (
      let delete_result =
        Caqti_eio_unix.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) -> Db.exec delete_query id)
          pool
      in
      match delete_result with
      | Error err -> Error (Pool.caqti_error_to_string err)
      | Ok () -> Ok true)
