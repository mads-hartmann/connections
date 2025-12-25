(* Row type definitions *)
let person_row_type = Caqti_type.(t2 int string)
let person_with_counts_row_type = Caqti_type.(t4 int string int int)

let insert_query =
  Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
    "INSERT INTO persons (name) VALUES (?) RETURNING id"

let get_query =
  Caqti_request.Infix.(Caqti_type.int ->? person_row_type)
    "SELECT id, name FROM persons WHERE id = ?"

let list_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* person_row_type)
    "SELECT id, name FROM persons ORDER BY id LIMIT ? OFFSET ?"

let count_query =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    "SELECT COUNT(*) FROM persons"

let list_filtered_query =
  Caqti_request.Infix.(Caqti_type.(t3 string int int) ->* person_row_type)
    "SELECT id, name FROM persons WHERE name LIKE ? ORDER BY name DESC LIMIT ? \
     OFFSET ?"

let count_filtered_query =
  Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
    "SELECT COUNT(*) FROM persons WHERE name LIKE ?"

let list_with_counts_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* person_with_counts_row_type)
    {|
      SELECT
        p.id,
        p.name,
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

let tuple_to_person (id, name) = { Model.Person.id; name }

let tuple_to_person_with_counts (id, name, feed_count, article_count) =
  { Model.Person.id; name; feed_count; article_count }

let create ~name =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.find insert_query name)
    pool
  |> Result.map (fun id -> { Model.Person.id; name })

let get ~id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
    pool
  |> Result.map (Option.map tuple_to_person)

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
      let+ () =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.exec update_query (name, id))
          pool
      in
      Some { Model.Person.id; name }

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
