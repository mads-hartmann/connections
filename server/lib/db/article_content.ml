(* Article content cache - stores markdown conversion of article HTML *)

let get_by_article_id_query =
  Caqti_request.Infix.(Caqti_type.int ->? Caqti_type.(t2 int string))
    "SELECT id, markdown FROM article_content WHERE article_id = ?"

let get_by_article_id ~article_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.find_opt get_by_article_id_query article_id)
    pool

let upsert_query =
  Caqti_request.Infix.(Caqti_type.(t2 int string) ->. Caqti_type.unit)
    {|
      INSERT INTO article_content (article_id, markdown)
      VALUES (?, ?)
      ON CONFLICT (article_id) DO UPDATE SET
        markdown = excluded.markdown,
        created_at = datetime('now')
    |}

let upsert ~article_id ~markdown =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec upsert_query (article_id, markdown))
    pool

let delete_by_article_id_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "DELETE FROM article_content WHERE article_id = ?"

let delete_by_article_id ~article_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec delete_by_article_id_query article_id)
    pool
