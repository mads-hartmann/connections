(* URI content cache - stores markdown conversion of URI HTML *)

let get_by_uri_id_query =
  Caqti_request.Infix.(Caqti_type.int ->? Caqti_type.(t2 int string))
    "SELECT id, markdown FROM uri_content WHERE uri_id = ?"

let get_by_uri_id ~uri_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.find_opt get_by_uri_id_query uri_id)
    pool

let upsert_query =
  Caqti_request.Infix.(Caqti_type.(t2 int string) ->. Caqti_type.unit)
    {|
      INSERT INTO uri_content (uri_id, markdown)
      VALUES (?, ?)
      ON CONFLICT (uri_id) DO UPDATE SET
        markdown = excluded.markdown,
        created_at = datetime('now')
    |}

let upsert ~uri_id ~markdown =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec upsert_query (uri_id, markdown))
    pool

let delete_by_uri_id_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "DELETE FROM uri_content WHERE uri_id = ?"

let delete_by_uri_id ~uri_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec delete_by_uri_id_query uri_id)
    pool
