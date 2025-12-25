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

(* UPSERT - returns true if inserted, false if duplicate *)

type create_input = {
  feed_id : int;
  title : string option;
  url : string;
  published_at : string option;
  content : string option;
  author : string option;
  image_url : string option;
}

let upsert (input : create_input) =
  let pool = Pool.get () in
  let { feed_id; title; url; published_at; content; author; image_url } =
    input
  in
  let params =
    (feed_id, title, url, published_at, content, author, image_url)
  in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.exec upsert_query params)
    pool

(* UPSERT MANY - returns count of inserted articles *)
let upsert_many inputs =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      let rec loop count = function
        | [] -> Ok count
        | input :: rest -> (
            let {
              feed_id;
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
            match Db.exec upsert_query params with
            | Error err -> Error err
            | Ok () -> loop (count + 1) rest)
      in
      loop 0 inputs)
    pool

(* GET *)
let get ~id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
    pool
  |> Result.map (Option.map tuple_to_article)

(* GET with tags *)
let get_with_tags ~id =
  let open Result.Syntax in
  let* article_opt = get ~id in
  match article_opt with
  | None -> Ok None
  | Some article ->
      let+ tags = Tag.get_by_article ~article_id:id in
      Some (Model.Article.add_tags article tags)

(* LIST BY FEED with pagination *)
let list_by_feed ~feed_id ~page ~per_page =
  let open Result.Syntax in
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let* total =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.find count_by_feed_query feed_id)
      pool
  in
  let+ rows =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.collect_list list_by_feed_query (feed_id, per_page, offset))
      pool
  in
  let data = List.map tuple_to_article rows in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total

(* LIST ALL with pagination and optional unread filter *)
let list_all ~page ~per_page ~unread_only =
  let open Result.Syntax in
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let* total =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        if unread_only then Db.find count_unread_query ()
        else Db.find count_all_query ())
      pool
  in
  let+ rows =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        if unread_only then Db.collect_list list_unread_query (per_page, offset)
        else Db.collect_list list_all_query (per_page, offset))
      pool
  in
  let data = List.map tuple_to_article rows in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total

(* LIST ALL with tags - eager loads tags for all articles *)
let list_all_with_tags ~page ~per_page ~unread_only =
  let open Result.Syntax in
  let* paginated = list_all ~page ~per_page ~unread_only in
  let article_ids =
    List.map (fun (a : Model.Article.t) -> a.id) paginated.data
  in
  if List.length article_ids = 0 then
    Ok
      (Model.Shared.Paginated.make ~data:[] ~page ~per_page
         ~total:paginated.total)
  else
    let+ tags_by_article = Tag.get_by_article_ids ~article_ids in
    let data =
      List.map
        (fun (article : Model.Article.t) ->
          let tags =
            Option.value ~default:[]
              (Hashtbl.find_opt tags_by_article article.id)
            |> List.rev
          in
          Model.Article.add_tags article tags)
        paginated.data
    in
    Model.Shared.Paginated.make ~data ~page ~per_page ~total:paginated.total

(* MARK READ/UNREAD *)
let mark_read ~id ~read =
  let open Result.Syntax in
  let pool = Pool.get () in
  let* exists =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find exists_query id)
      pool
  in
  match exists with
  | 0 -> Ok None
  | _ ->
      let read_at =
        if read then
          let now = Unix.gettimeofday () in
          let tm = Unix.gmtime now in
          Some
            (Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d"
               (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday
               tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec)
        else None
      in
      let* () =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.exec mark_read_query (read_at, id))
          pool
      in
      get ~id

(* MARK ALL READ for a feed *)
let mark_all_read ~feed_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.collect_list mark_all_read_query feed_id)
    pool
  |> Result.map List.length

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
