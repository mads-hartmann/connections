open Lwt.Syntax

(* Query definitions *)
let create_table_query =
  Caqti_request.Infix.(Caqti_type.unit ->. Caqti_type.unit)
    {|
      CREATE TABLE IF NOT EXISTS persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    |}

let insert_query =
  Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
    "INSERT INTO persons (name) VALUES (?) RETURNING id"

let get_query =
  Caqti_request.Infix.(Caqti_type.int ->? Caqti_type.(t2 int string))
    "SELECT id, name FROM persons WHERE id = ?"

let list_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* Caqti_type.(t2 int string))
    "SELECT id, name FROM persons ORDER BY id LIMIT ? OFFSET ?"

let count_query =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    "SELECT COUNT(*) FROM persons"

let list_filtered_query =
  Caqti_request.Infix.(
    Caqti_type.(t3 string int int) ->* Caqti_type.(t2 int string))
    "SELECT id, name FROM persons WHERE name LIKE ? ORDER BY name DESC LIMIT ? \
     OFFSET ?"

let count_filtered_query =
  Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
    "SELECT COUNT(*) FROM persons WHERE name LIKE ?"

let list_with_counts_query =
  Caqti_request.Infix.(
    Caqti_type.(t2 int int) ->* Caqti_type.(t4 int string int int))
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
    Caqti_type.(t3 string int int) ->* Caqti_type.(t4 int string int int))
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

let init_table () =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) -> Db.exec create_table_query ())
      pool
  in
  match result with
  | Error err ->
      Lwt.fail_with
        (Format.asprintf "Table creation error: %a" Caqti_error.pp err)
  | Ok () -> Lwt.return_unit

let create ~name =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find insert_query name)
      pool
  in
  match result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok id -> Lwt.return_ok { Model.Person.id; name }

let get ~id =
  let pool = Pool.get () in
  let* result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find_opt get_query id)
      pool
  in
  match result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok None -> Lwt.return_ok None
  | Ok (Some (id, name)) -> Lwt.return_ok (Some { Model.Person.id; name })

let list ~page ~per_page ?query () =
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let* count_result =
    match query with
    | None ->
        Caqti_lwt_unix.Pool.use
          (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find count_query ())
          pool
    | Some q ->
        let pattern = "%" ^ q ^ "%" in
        Caqti_lwt_unix.Pool.use
          (fun (module Db : Caqti_lwt.CONNECTION) ->
            Db.find count_filtered_query pattern)
          pool
  in
  match count_result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok total -> (
      let* list_result =
        match query with
        | None ->
            Caqti_lwt_unix.Pool.use
              (fun (module Db : Caqti_lwt.CONNECTION) ->
                Db.collect_list list_query (per_page, offset))
              pool
        | Some q ->
            let pattern = "%" ^ q ^ "%" in
            Caqti_lwt_unix.Pool.use
              (fun (module Db : Caqti_lwt.CONNECTION) ->
                Db.collect_list list_filtered_query (pattern, per_page, offset))
              pool
      in
      match list_result with
      | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
      | Ok rows ->
          let persons =
            List.map (fun (id, name) -> { Model.Person.id; name }) rows
          in
          let total_pages = (total + per_page - 1) / per_page in
          let response : Model.Person.paginated_response =
            { data = persons; page; per_page; total; total_pages }
          in
          Lwt.return_ok response)

let update ~id ~name =
  let pool = Pool.get () in
  let* exists_result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find exists_query id)
      pool
  in
  match exists_result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok 0 -> Lwt.return_ok None
  | Ok _ -> (
      let* update_result =
        Caqti_lwt_unix.Pool.use
          (fun (module Db : Caqti_lwt.CONNECTION) ->
            Db.exec update_query (name, id))
          pool
      in
      match update_result with
      | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
      | Ok () -> Lwt.return_ok (Some { Model.Person.id; name }))

let delete ~id =
  let pool = Pool.get () in
  let* exists_result =
    Caqti_lwt_unix.Pool.use
      (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find exists_query id)
      pool
  in
  match exists_result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok 0 -> Lwt.return_ok false
  | Ok _ -> (
      let* delete_result =
        Caqti_lwt_unix.Pool.use
          (fun (module Db : Caqti_lwt.CONNECTION) -> Db.exec delete_query id)
          pool
      in
      match delete_result with
      | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
      | Ok () -> Lwt.return_ok true)

let list_with_counts ~page ~per_page ?query () =
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let* count_result =
    match query with
    | None ->
        Caqti_lwt_unix.Pool.use
          (fun (module Db : Caqti_lwt.CONNECTION) -> Db.find count_query ())
          pool
    | Some q ->
        let pattern = "%" ^ q ^ "%" in
        Caqti_lwt_unix.Pool.use
          (fun (module Db : Caqti_lwt.CONNECTION) ->
            Db.find count_filtered_query pattern)
          pool
  in
  match count_result with
  | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
  | Ok total -> (
      let* list_result =
        match query with
        | None ->
            Caqti_lwt_unix.Pool.use
              (fun (module Db : Caqti_lwt.CONNECTION) ->
                Db.collect_list list_with_counts_query (per_page, offset))
              pool
        | Some q ->
            let pattern = "%" ^ q ^ "%" in
            Caqti_lwt_unix.Pool.use
              (fun (module Db : Caqti_lwt.CONNECTION) ->
                Db.collect_list list_with_counts_filtered_query
                  (pattern, per_page, offset))
              pool
      in
      match list_result with
      | Error err -> Lwt.return_error (Pool.caqti_error_to_string err)
      | Ok rows ->
          let persons =
            List.map
              (fun (id, name, feed_count, article_count) ->
                { Model.Person.id; name; feed_count; article_count })
              rows
          in
          let total_pages = (total + per_page - 1) / per_page in
          let response : Model.Person.paginated_response_with_counts =
            { data = persons; page; per_page; total; total_pages }
          in
          Lwt.return_ok response)
