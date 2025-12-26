(* Row type definitions - 3 fields with tags JSON *)
let person_row_type = Caqti_type.(t3 int string string)
let person_with_counts_row_type = Caqti_type.(t5 int string string int int)

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
        COUNT(a.id) as article_count
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
        COUNT(a.id) as article_count
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

(* Parse tags JSON string into Tag.t list *)
let parse_tags_json (json_str : string) : Model.Tag.t list =
  try
    match Yojson.Safe.from_string json_str with
    | `List items ->
        List.filter_map
          (fun item ->
            match item with
            | `Assoc fields -> (
                let id =
                  Option.bind (List.assoc_opt "id" fields) (function
                    | `Int i -> Some i
                    | _ -> None)
                in
                let name =
                  Option.bind (List.assoc_opt "name" fields) (function
                    | `String s -> Some s
                    | _ -> None)
                in
                match (id, name) with
                | Some id, Some name -> Some { Model.Tag.id; name }
                | _ -> None)
            | _ -> None)
          items
    | _ -> []
  with _ -> []

let tuple_to_person (id, name, tags_json) =
  { Model.Person.id; name; tags = parse_tags_json tags_json }

let tuple_to_person_with_counts (id, name, tags_json, feed_count, article_count)
    =
  {
    Model.Person.id;
    name;
    tags = parse_tags_json tags_json;
    feed_count;
    article_count;
  }

let get ~id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
    pool
  |> Result.map (Option.map tuple_to_person)

let create ~name =
  let open Result.Syntax in
  let pool = Pool.get () in
  let* id =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find insert_query name)
      pool
  in
  get ~id |> Result.map (Option.get)

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
  let+ rows =
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
  let data = List.map tuple_to_person_with_counts rows in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total
