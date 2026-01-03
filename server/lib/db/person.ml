(* Row type definitions - 3 fields with tags JSON *)
let person_row_type = Caqti_type.(t3 int string string)
let person_with_counts_row_type = Caqti_type.(t6 int string string int int int)
let metadata_row_type = Caqti_type.(t4 int int int string)

let insert_query =
  Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
    "INSERT INTO persons (name) VALUES (?) RETURNING id"

(* Base SELECT with tags JSON aggregation *)
let select_with_tags =
  {|
    SELECT p.id, p.name,
           COALESCE((SELECT json_group_array(json_object('id', t.id, 'name', t.name))
                     FROM person_tags pt
                     JOIN tags t ON pt.tag_id = t.id
                     WHERE pt.person_id = p.id), '[]') as tags
    FROM persons p
  |}

let get_query =
  Caqti_request.Infix.(Caqti_type.int ->? person_row_type)
    (select_with_tags ^ " WHERE p.id = ?")

let list_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* person_row_type)
    (select_with_tags ^ " ORDER BY p.id LIMIT ? OFFSET ?")

let count_query =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    "SELECT COUNT(*) FROM persons"

let list_filtered_query =
  Caqti_request.Infix.(Caqti_type.(t3 string int int) ->* person_row_type)
    (select_with_tags
   ^ " WHERE p.name LIKE ? ORDER BY p.name DESC LIMIT ? OFFSET ?")

let count_filtered_query =
  Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
    "SELECT COUNT(*) FROM persons WHERE name LIKE ?"

let list_with_counts_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* person_with_counts_row_type)
    {|
      SELECT
        p.id,
        p.name,
        COALESCE((SELECT json_group_array(json_object('id', t.id, 'name', t.name))
                  FROM person_tags pt
                  JOIN tags t ON pt.tag_id = t.id
                  WHERE pt.person_id = p.id), '[]') as tags,
        COUNT(DISTINCT f.id) as feed_count,
        COUNT(a.id) as article_count,
        COUNT(CASE WHEN a.read_at IS NULL THEN 1 END) as unread_article_count
      FROM persons p
      LEFT JOIN rss_feeds f ON f.person_id = p.id
      LEFT JOIN articles a ON a.feed_id = f.id
      GROUP BY p.id
      ORDER BY p.id
      LIMIT ? OFFSET ?
    |}

let list_with_counts_filtered_query =
  Caqti_request.Infix.(
    Caqti_type.(t3 string int int) ->* person_with_counts_row_type)
    {|
      SELECT
        p.id,
        p.name,
        COALESCE((SELECT json_group_array(json_object('id', t.id, 'name', t.name))
                  FROM person_tags pt
                  JOIN tags t ON pt.tag_id = t.id
                  WHERE pt.person_id = p.id), '[]') as tags,
        COUNT(DISTINCT f.id) as feed_count,
        COUNT(a.id) as article_count,
        COUNT(CASE WHEN a.read_at IS NULL THEN 1 END) as unread_article_count
      FROM persons p
      LEFT JOIN rss_feeds f ON f.person_id = p.id
      LEFT JOIN articles a ON a.feed_id = f.id
      WHERE p.name LIKE ?
      GROUP BY p.id
      ORDER BY p.name DESC
      LIMIT ? OFFSET ?
    |}

let update_query =
  Caqti_request.Infix.(Caqti_type.(t2 string int) ->. Caqti_type.unit)
    "UPDATE persons SET name = ? WHERE id = ?"

let delete_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "DELETE FROM persons WHERE id = ?"

let exists_query =
  Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
    "SELECT COUNT(*) FROM persons WHERE id = ?"

let metadata_by_person_query =
  Caqti_request.Infix.(Caqti_type.int ->* metadata_row_type)
    {|
      SELECT pm.id, pm.person_id, pm.field_type_id, pm.value
      FROM person_metadata pm
      JOIN metadata_field_types mft ON mft.id = pm.field_type_id
      WHERE pm.person_id = ?
      ORDER BY mft.name ASC
    |}

let metadata_by_person_ids_query ids =
  let placeholders = String.concat ", " (List.map string_of_int ids) in
  Caqti_request.Infix.(Caqti_type.unit ->* metadata_row_type)
    (Printf.sprintf
       {|
      SELECT pm.id, pm.person_id, pm.field_type_id, pm.value
      FROM person_metadata pm
      JOIN metadata_field_types mft ON mft.id = pm.field_type_id
      WHERE pm.person_id IN (%s)
      ORDER BY mft.name ASC
    |}
       placeholders)

let tuple_to_metadata (id, person_id, field_type_id, value) =
  Option.map
    (fun field_type ->
      Model.Person_metadata.create ~id ~person_id ~field_type ~value)
    (Model.Metadata_field_type.of_id field_type_id)

let group_metadata_by_person metadata =
  let tbl = Hashtbl.create 16 in
  List.iter
    (fun m ->
      let pid = Model.Person_metadata.person_id m in
      let existing = Option.value ~default:[] (Hashtbl.find_opt tbl pid) in
      Hashtbl.replace tbl pid (m :: existing))
    metadata;
  Hashtbl.iter (fun k v -> Hashtbl.replace tbl k (List.rev v)) tbl;
  tbl

let tuple_to_person (id, name, tags_json) =
  Model.Person.create ~id ~name ~tags:(Tag_json.parse tags_json) ~metadata:[]

let tuple_to_person_with_counts
    (id, name, tags_json, feed_count, article_count, unread_article_count) =
  Model.Person.create_with_counts ~id ~name ~tags:(Tag_json.parse tags_json)
    ~feed_count ~article_count ~unread_article_count ~metadata:[]

let attach_metadata_with_counts metadata_tbl
    (person : Model.Person.t_with_counts) =
  let metadata =
    Option.value ~default:[]
      (Hashtbl.find_opt metadata_tbl (Model.Person.id_with_counts person))
  in
  Model.Person.with_metadata_counts person metadata

let get ~id =
  let open Result.Syntax in
  let pool = Pool.get () in
  let* person_opt =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
      pool
  in
  match person_opt with
  | None -> Ok None
  | Some row ->
      let person = tuple_to_person row in
      let+ metadata_rows =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.collect_list metadata_by_person_query (Model.Person.id person))
          pool
      in
      let metadata = List.filter_map tuple_to_metadata metadata_rows in
      Some (Model.Person.with_metadata person metadata)

let create ~name =
  let open Result.Syntax in
  let pool = Pool.get () in
  let* id =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find insert_query name)
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
  let data = List.map tuple_to_person rows in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total

let update ~id ~name =
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
            Db.exec update_query (name, id))
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
      let* () = Article.delete_by_person_id ~person_id:id in
      let* () = Rss_feed.delete_by_person_id ~person_id:id in
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
  let persons = List.map tuple_to_person_with_counts rows in
  let person_ids = List.map Model.Person.id_with_counts persons in
  let+ metadata_tbl =
    if List.length person_ids = 0 then Ok (Hashtbl.create 0)
    else
      let query = metadata_by_person_ids_query person_ids in
      Caqti_eio.Pool.use
        (fun (module Db : Caqti_eio.CONNECTION) -> Db.collect_list query ())
        pool
      |> Result.map (fun rows ->
          group_metadata_by_person (List.filter_map tuple_to_metadata rows))
  in
  let data = List.map (attach_metadata_with_counts metadata_tbl) persons in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total
