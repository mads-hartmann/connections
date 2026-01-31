(* Row type definitions - 4 fields with tags JSON *)
let connection_row_type = Caqti_type.(t4 int string (option string) string)

let connection_with_counts_row_type =
  Caqti_type.(t7 int string (option string) string int int int)

let metadata_row_type = Caqti_type.(t4 int int int string)

let insert_query =
  Caqti_request.Infix.(Caqti_type.(t2 string (option string)) ->! Caqti_type.int)
    "INSERT INTO connections (name, photo) VALUES (?, ?) RETURNING id"

(* Base SELECT with tags JSON aggregation *)
let select_with_tags =
  {|
    SELECT c.id, c.name, c.photo,
           COALESCE((SELECT json_group_array(json_object('id', t.id, 'name', t.name))
                     FROM connection_tags ct
                     JOIN tags t ON ct.tag_id = t.id
                     WHERE ct.connection_id = c.id), '[]') as tags
    FROM connections c
  |}

let get_query =
  Caqti_request.Infix.(Caqti_type.int ->? connection_row_type)
    (select_with_tags ^ " WHERE c.id = ?")

let list_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* connection_row_type)
    (select_with_tags ^ " ORDER BY c.name ASC LIMIT ? OFFSET ?")

let count_query =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    "SELECT COUNT(*) FROM connections"

let list_filtered_query =
  Caqti_request.Infix.(Caqti_type.(t3 string int int) ->* connection_row_type)
    (select_with_tags
   ^ " WHERE c.name LIKE ? ORDER BY c.name ASC LIMIT ? OFFSET ?")

let count_filtered_query =
  Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
    "SELECT COUNT(*) FROM connections WHERE name LIKE ?"

let list_with_counts_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* connection_with_counts_row_type)
    {|
      SELECT
        c.id,
        c.name,
        c.photo,
        COALESCE((SELECT json_group_array(json_object('id', t.id, 'name', t.name))
                  FROM connection_tags ct
                  JOIN tags t ON ct.tag_id = t.id
                  WHERE ct.connection_id = c.id), '[]') as tags,
        COUNT(DISTINCT f.id) as feed_count,
        COUNT(u.id) as uri_count,
        COUNT(CASE WHEN u.read_at IS NULL THEN 1 END) as unread_uri_count
      FROM connections c
      LEFT JOIN rss_feeds f ON f.connection_id = c.id
      LEFT JOIN uris u ON u.connection_id = c.id
      GROUP BY c.id
      ORDER BY
        CASE WHEN COUNT(CASE WHEN u.read_at IS NULL THEN 1 END) > 0 THEN 0 ELSE 1 END,
        c.name ASC
      LIMIT ? OFFSET ?
    |}

let list_with_counts_filtered_query =
  Caqti_request.Infix.(
    Caqti_type.(t3 string int int) ->* connection_with_counts_row_type)
    {|
      SELECT
        c.id,
        c.name,
        c.photo,
        COALESCE((SELECT json_group_array(json_object('id', t.id, 'name', t.name))
                  FROM connection_tags ct
                  JOIN tags t ON ct.tag_id = t.id
                  WHERE ct.connection_id = c.id), '[]') as tags,
        COUNT(DISTINCT f.id) as feed_count,
        COUNT(u.id) as uri_count,
        COUNT(CASE WHEN u.read_at IS NULL THEN 1 END) as unread_uri_count
      FROM connections c
      LEFT JOIN rss_feeds f ON f.connection_id = c.id
      LEFT JOIN uris u ON u.connection_id = c.id
      WHERE c.name LIKE ?
      GROUP BY c.id
      ORDER BY
        CASE WHEN COUNT(CASE WHEN u.read_at IS NULL THEN 1 END) > 0 THEN 0 ELSE 1 END,
        c.name ASC
      LIMIT ? OFFSET ?
    |}

let update_query =
  Caqti_request.Infix.(
    Caqti_type.(t3 string (option string) int) ->. Caqti_type.unit)
    "UPDATE connections SET name = ?, photo = ? WHERE id = ?"

let delete_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "DELETE FROM connections WHERE id = ?"

let exists_query =
  Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
    "SELECT COUNT(*) FROM connections WHERE id = ?"

let metadata_by_connection_query =
  Caqti_request.Infix.(Caqti_type.int ->* metadata_row_type)
    {|
      SELECT cm.id, cm.connection_id, cm.field_type_id, cm.value
      FROM connection_metadata cm
      JOIN metadata_field_types mft ON mft.id = cm.field_type_id
      WHERE cm.connection_id = ?
      ORDER BY mft.name ASC
    |}

let metadata_by_connection_ids_query ids =
  let placeholders = String.concat ", " (List.map string_of_int ids) in
  Caqti_request.Infix.(Caqti_type.unit ->* metadata_row_type)
    (Printf.sprintf
       {|
      SELECT cm.id, cm.connection_id, cm.field_type_id, cm.value
      FROM connection_metadata cm
      JOIN metadata_field_types mft ON mft.id = cm.field_type_id
      WHERE cm.connection_id IN (%s)
      ORDER BY mft.name ASC
    |}
       placeholders)

let tuple_to_metadata (id, connection_id, field_type_id, value) =
  Option.map
    (fun field_type ->
      Model.Connection_metadata.create ~id ~connection_id ~field_type ~value)
    (Model.Metadata_field_type.of_id field_type_id)

let group_metadata_by_connection metadata =
  let tbl = Hashtbl.create 16 in
  List.iter
    (fun m ->
      let cid = Model.Connection_metadata.connection_id m in
      let existing = Option.value ~default:[] (Hashtbl.find_opt tbl cid) in
      Hashtbl.replace tbl cid (m :: existing))
    metadata;
  Hashtbl.iter (fun k v -> Hashtbl.replace tbl k (List.rev v)) tbl;
  tbl

let tuple_to_connection (id, name, photo, tags_json) =
  Model.Connection.create ~id ~name ~photo ~tags:(Tag_json.parse tags_json)
    ~metadata:[]

let tuple_to_connection_with_counts
    (id, name, photo, tags_json, feed_count, uri_count, unread_uri_count)
    =
  Model.Connection.create_with_counts ~id ~name ~photo
    ~tags:(Tag_json.parse tags_json) ~feed_count ~uri_count
    ~unread_uri_count ~metadata:[]

let attach_metadata_with_counts metadata_tbl
    (connection : Model.Connection.t_with_counts) =
  let metadata =
    Option.value ~default:[]
      (Hashtbl.find_opt metadata_tbl (Model.Connection.id_with_counts connection))
  in
  Model.Connection.with_metadata_counts connection metadata

let get ~id =
  let open Result.Syntax in
  let pool = Pool.get () in
  let* connection_opt =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
      pool
  in
  match connection_opt with
  | None -> Ok None
  | Some row ->
      let connection = tuple_to_connection row in
      let+ metadata_rows =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.collect_list metadata_by_connection_query (Model.Connection.id connection))
          pool
      in
      let metadata = List.filter_map tuple_to_metadata metadata_rows in
      Some (Model.Connection.with_metadata connection metadata)

let create ~name ?photo () =
  let open Result.Syntax in
  let pool = Pool.get () in
  let* id =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.find insert_query (name, photo))
      pool
  in
  get ~id |> Result.map Option.get

let list ~page ~per_page ?query () =
  let open Result.Syntax in
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let pattern = Option.map (fun q -> "%" ^ q ^ "%") query in
  let* total =
    match pattern with
    | None ->
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) -> Db.find count_query ())
          pool
    | Some p ->
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.find count_filtered_query p)
          pool
  in
  let+ rows =
    match pattern with
    | None ->
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.collect_list list_query (per_page, offset))
          pool
    | Some p ->
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.collect_list list_filtered_query (p, per_page, offset))
          pool
  in
  let data = List.map tuple_to_connection rows in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total

let update ~id ~name ~photo =
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
      let* () =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.exec update_query (name, photo, id))
          pool
      in
      get ~id

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
      let* () = Uri_store.delete_by_connection_id ~connection_id:id in
      let* () = Rss_feed.delete_by_connection_id ~connection_id:id in
      let+ () =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) -> Db.exec delete_query id)
          pool
      in
      true

let list_with_counts ~page ~per_page ?query () =
  let open Result.Syntax in
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let pattern = Option.map (fun q -> "%" ^ q ^ "%") query in
  let* total =
    match pattern with
    | None ->
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) -> Db.find count_query ())
          pool
    | Some p ->
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.find count_filtered_query p)
          pool
  in
  let* rows =
    match pattern with
    | None ->
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.collect_list list_with_counts_query (per_page, offset))
          pool
    | Some p ->
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.collect_list list_with_counts_filtered_query (p, per_page, offset))
          pool
  in
  let connections = List.map tuple_to_connection_with_counts rows in
  let connection_ids = List.map Model.Connection.id_with_counts connections in
  let+ metadata_tbl =
    if List.length connection_ids = 0 then Ok (Hashtbl.create 0)
    else
      let query = metadata_by_connection_ids_query connection_ids in
      Caqti_eio.Pool.use
        (fun (module Db : Caqti_eio.CONNECTION) -> Db.collect_list query ())
        pool
      |> Result.map (fun rows ->
          group_metadata_by_connection (List.filter_map tuple_to_metadata rows))
  in
  let data = List.map (attach_metadata_with_counts metadata_tbl) connections in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total
