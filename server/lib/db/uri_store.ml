(* URI row type with connection, tags JSON and OG fields: 21 fields *)
(* Split as t2 of (t2 of (t6, t2), t2 of (t7, t6)) *)
let uri_row_type =
  Caqti_type.(
    t2
      (t2
         (t6 int (option int) (option int) (option string) int (option string))
         (t2 string (option string)))
      (t2
         (t7 (option string) (option string) (option string) string
            (option string) (option string) string)
         (t6 (option string) (option string) (option string) (option string)
            (option string) (option string))))

(* Upsert input type: 9 fields *)
let upsert_input_type =
  Caqti_type.(
    t2
      (t5 int (option int) int (option string) string)
      (t4 (option string) (option string) (option string) (option string)))

(* Create input type: 4 fields for manual URI creation *)
let create_input_type =
  Caqti_type.(t4 (option int) int string (option string))

let base_select =
  {|
    SELECT
      u.id,
      u.feed_id,
      u.connection_id,
      c.name as connection_name,
      u.kind_id,
      u.title,
      u.url,
      u.published_at,
      u.content,
      u.author,
      u.image_url,
      u.created_at,
      u.read_at,
      u.read_later_at,
      COALESCE((SELECT json_group_array(json_object('id', t.id, 'name', t.name))
                FROM uri_tags ut
                JOIN tags t ON ut.tag_id = t.id
                WHERE ut.uri_id = u.id), '[]') as tags,
      u.og_title,
      u.og_description,
      u.og_image,
      u.og_site_name,
      u.og_fetched_at,
      u.og_fetch_error
    FROM uris u
    LEFT JOIN connections c ON u.connection_id = c.id
  |}

let get_query =
  Caqti_request.Infix.(Caqti_type.int ->? uri_row_type)
    (base_select ^ " WHERE u.id = ?")

let list_by_feed_query =
  Caqti_request.Infix.(Caqti_type.(t3 int int int) ->* uri_row_type)
    (base_select
   ^ " WHERE u.feed_id = ? ORDER BY u.published_at DESC NULLS LAST LIMIT ? \
      OFFSET ?")

let count_by_feed_query =
  Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
    "SELECT COUNT(*) FROM uris WHERE feed_id = ?"

let list_by_connection_query =
  Caqti_request.Infix.(Caqti_type.(t4 int bool int int) ->* uri_row_type)
    (base_select
   ^ " WHERE u.connection_id = ? AND (? = false OR u.read_at IS NULL) ORDER BY \
      u.published_at DESC NULLS LAST LIMIT ? OFFSET ?")

let count_by_connection_query =
  Caqti_request.Infix.(Caqti_type.(t2 int bool) ->! Caqti_type.int)
    "SELECT COUNT(*) FROM uris WHERE connection_id = ? AND (? = false OR \
     read_at IS NULL)"

let list_all_base =
  base_select
  ^ {| WHERE (? = false OR u.read_at IS NULL)
       AND (? = false OR u.read_later_at IS NOT NULL)
       AND (? IS NULL OR u.id IN (SELECT uri_id FROM uri_tags ut JOIN tags t ON ut.tag_id = t.id WHERE t.name = ?))
       AND (? IS NULL OR u.title LIKE ? OR u.url LIKE ? OR u.og_title LIKE ?)
       AND (? = false OR u.connection_id IS NULL)
       ORDER BY u.published_at DESC NULLS LAST
       LIMIT ? OFFSET ?
  |}

let list_all_query =
  Caqti_request.Infix.(
    Caqti_type.(
      t2
        (t5 bool bool (option string) (option string) (option string))
        (t2 (t5 (option string) (option string) (option string) bool int) int))
    ->* uri_row_type)
    list_all_base

let count_all_query =
  Caqti_request.Infix.(
    Caqti_type.(
      t2
        (t4 bool bool (option string) (option string))
        (t4 (option string) (option string) (option string) bool))
    ->! Caqti_type.int)
    {|
      SELECT COUNT(*) FROM uris u
      WHERE (? = false OR u.read_at IS NULL)
        AND (? = false OR u.read_later_at IS NOT NULL)
        AND (? IS NULL OR u.id IN (SELECT uri_id FROM uri_tags ut JOIN tags t ON ut.tag_id = t.id WHERE t.name = ?))
        AND (? IS NULL OR u.title LIKE ? OR u.url LIKE ? OR u.og_title LIKE ?)
        AND (? = false OR u.connection_id IS NULL)
    |}

let upsert_query =
  Caqti_request.Infix.(upsert_input_type ->! Caqti_type.int)
    {|
      INSERT INTO uris (feed_id, connection_id, kind_id, title, url, published_at, content, author, image_url)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(feed_id, url) WHERE feed_id IS NOT NULL DO UPDATE SET
        title = excluded.title,
        published_at = excluded.published_at,
        content = excluded.content,
        author = excluded.author,
        image_url = excluded.image_url
      RETURNING id
    |}

let create_query =
  Caqti_request.Infix.(create_input_type ->! Caqti_type.int)
    {|
      INSERT INTO uris (connection_id, kind_id, url, title)
      VALUES (?, ?, ?, ?)
      RETURNING id
    |}

let update_query =
  Caqti_request.Infix.(
    Caqti_type.(t4 (option int) int (option string) int) ->. Caqti_type.unit)
    "UPDATE uris SET connection_id = ?, kind_id = ?, title = ? WHERE id = ?"

let mark_read_query =
  Caqti_request.Infix.(Caqti_type.(t2 (option string) int) ->. Caqti_type.unit)
    "UPDATE uris SET read_at = ? WHERE id = ?"

let mark_read_later_query =
  Caqti_request.Infix.(Caqti_type.(t2 (option string) int) ->. Caqti_type.unit)
    "UPDATE uris SET read_later_at = ? WHERE id = ?"

let mark_all_read_by_feed_query =
  Caqti_request.Infix.(Caqti_type.(t2 string int) ->! Caqti_type.int)
    {|
      UPDATE uris SET read_at = ?
      WHERE feed_id = ? AND read_at IS NULL
      RETURNING id
    |}

let mark_all_read_global_query =
  Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
    {|
      WITH updated AS (
        UPDATE uris SET read_at = ?
        WHERE read_at IS NULL
        RETURNING id
      )
      SELECT COUNT(*) FROM updated
    |}

let delete_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "DELETE FROM uris WHERE id = ?"

let exists_query =
  Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
    "SELECT COUNT(*) FROM uris WHERE id = ?"

let delete_by_connection_id_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "DELETE FROM uris WHERE connection_id = ?"

let update_og_metadata_query =
  Caqti_request.Infix.(
    Caqti_type.(
      t2
        (t4 (option string) (option string) (option string) (option string))
        (t3 string (option string) int))
    ->. Caqti_type.unit)
    {|
      UPDATE uris SET
        og_title = ?,
        og_description = ?,
        og_image = ?,
        og_site_name = ?,
        og_fetched_at = ?,
        og_fetch_error = ?
      WHERE id = ?
    |}

let list_needing_og_metadata_query =
  Caqti_request.Infix.(Caqti_type.int ->* uri_row_type)
    (base_select ^ " WHERE u.og_fetched_at IS NULL LIMIT ?")

let tuple_to_uri
    ( ( (id, feed_id, connection_id, connection_name, kind_id, title),
        (url, published_at) ),
      ( (content, author, image_url, created_at, read_at, read_later_at, tags_json),
        (og_title, og_description, og_image, og_site_name, og_fetched_at, og_fetch_error) ) ) =
  let kind = Model.Uri_kind.of_id_exn kind_id in
  Model.Uri_entry.create ~id ~feed_id ~connection_id ~connection_name ~kind ~title ~url
    ~published_at ~content ~author ~image_url ~created_at ~read_at ~read_later_at
    ~tags:(Tag_json.parse tags_json) ~og_title ~og_description ~og_image
    ~og_site_name ~og_fetched_at ~og_fetch_error

let get ~id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
    pool
  |> Result.map (Option.map tuple_to_uri)

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
  let data = List.map tuple_to_uri rows in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total

let list_by_connection ~connection_id ~page ~per_page ~unread_only =
  let open Result.Syntax in
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let* total =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.find count_by_connection_query (connection_id, unread_only))
      pool
  in
  let+ rows =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.collect_list list_by_connection_query
          (connection_id, unread_only, per_page, offset))
      pool
  in
  let data = List.map tuple_to_uri rows in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total

let list_all ~page ~per_page ~unread_only ~read_later_only ~tag ~orphan_only ?query () =
  let open Result.Syntax in
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let pattern = Option.map (fun q -> "%" ^ q ^ "%") query in
  let* total =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.find count_all_query
          ((unread_only, read_later_only, tag, tag), (pattern, pattern, pattern, orphan_only)))
      pool
  in
  let+ rows =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.collect_list list_all_query
          ( (unread_only, read_later_only, tag, tag, pattern),
            ((pattern, pattern, pattern, orphan_only, per_page), offset) ))
      pool
  in
  let data = List.map tuple_to_uri rows in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total

let upsert ~feed_id ~connection_id ~kind ~title ~url ~published_at ~content
    ~author ~image_url =
  let open Result.Syntax in
  let pool = Pool.get () in
  let kind_id = Model.Uri_kind.to_id kind in
  let* id =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.find upsert_query
          ((feed_id, connection_id, kind_id, title, url), (published_at, content, author, image_url)))
      pool
  in
  get ~id |> Result.map Option.get

let create ~connection_id ~kind ~url ~title =
  let open Result.Syntax in
  let pool = Pool.get () in
  let kind_id = Model.Uri_kind.to_id kind in
  let* id =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.find create_query (connection_id, kind_id, url, title))
      pool
  in
  get ~id |> Result.map Option.get

let update ~id ~connection_id ~kind ~title =
  let open Result.Syntax in
  let pool = Pool.get () in
  let kind_id = Model.Uri_kind.to_id kind in
  let* exists =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find exists_query id)
      pool
  in
  match exists with
  | 0 -> Ok None
  | _ ->
      let* () =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.exec update_query (connection_id, kind_id, title, id))
          pool
      in
      get ~id

let mark_read ~id ~read =
  let open Result.Syntax in
  let pool = Pool.get () in
  let now = if read then Some (Ptime_clock.now () |> Ptime.to_rfc3339) else None in
  let* () =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.exec mark_read_query (now, id))
      pool
  in
  get ~id

let mark_read_later ~id ~read_later =
  let open Result.Syntax in
  let pool = Pool.get () in
  let now =
    if read_later then Some (Ptime_clock.now () |> Ptime.to_rfc3339) else None
  in
  let* () =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.exec mark_read_later_query (now, id))
      pool
  in
  get ~id

let mark_all_read ~feed_id =
  let pool = Pool.get () in
  let now = Ptime_clock.now () |> Ptime.to_rfc3339 in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.fold mark_all_read_by_feed_query
        (fun _id count -> count + 1)
        (now, feed_id) 0)
    pool

let mark_all_read_global () =
  let pool = Pool.get () in
  let now = Ptime_clock.now () |> Ptime.to_rfc3339 in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.find mark_all_read_global_query now)
    pool

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

let delete_by_connection_id ~connection_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec delete_by_connection_id_query connection_id)
    pool

let update_og_metadata ~id ~og_title ~og_description ~og_image ~og_site_name
    ~og_fetch_error =
  let open Result.Syntax in
  let pool = Pool.get () in
  let now = Ptime_clock.now () |> Ptime.to_rfc3339 in
  let* () =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.exec update_og_metadata_query
          ((og_title, og_description, og_image, og_site_name), (now, og_fetch_error, id)))
      pool
  in
  get ~id

let list_needing_og_metadata ~limit =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.collect_list list_needing_og_metadata_query limit)
    pool
  |> Result.map (List.map tuple_to_uri)
