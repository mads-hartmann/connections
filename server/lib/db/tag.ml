(* Row type definitions *)
let tag_row_type = Caqti_type.(t2 int string)

let insert_query =
  Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
    "INSERT INTO tags (name) VALUES (?) RETURNING id"

let get_query =
  Caqti_request.Infix.(Caqti_type.int ->? tag_row_type)
    "SELECT id, name FROM tags WHERE id = ?"

let get_by_name_query =
  Caqti_request.Infix.(Caqti_type.string ->? tag_row_type)
    "SELECT id, name FROM tags WHERE name = ?"

let list_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->* tag_row_type)
    "SELECT id, name FROM tags ORDER BY name LIMIT ? OFFSET ?"

let list_all_query =
  Caqti_request.Infix.(Caqti_type.unit ->* tag_row_type)
    "SELECT id, name FROM tags ORDER BY name"

let count_query =
  Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.int)
    "SELECT COUNT(*) FROM tags"

let delete_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "DELETE FROM tags WHERE id = ?"

let exists_query =
  Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
    "SELECT COUNT(*) FROM tags WHERE id = ?"

let add_to_person_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->. Caqti_type.unit)
    "INSERT OR IGNORE INTO person_tags (person_id, tag_id) VALUES (?, ?)"

let remove_from_person_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->. Caqti_type.unit)
    "DELETE FROM person_tags WHERE person_id = ? AND tag_id = ?"

let get_by_person_query =
  Caqti_request.Infix.(Caqti_type.int ->* tag_row_type)
    "SELECT t.id, t.name FROM tags t INNER JOIN person_tags pt ON t.id = \
     pt.tag_id WHERE pt.person_id = ? ORDER BY t.name"

let tuple_to_tag (id, name) = { Model.Tag.id; name }

let create ~name =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.find insert_query name)
    pool
  |> Result.map (fun id -> { Model.Tag.id; name })

let get ~id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
    pool
  |> Result.map (Option.map tuple_to_tag)

let get_by_name ~name =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.find_opt get_by_name_query name)
    pool
  |> Result.map (Option.map tuple_to_tag)

let get_or_create ~name =
  let open Result.Syntax in
  let* existing = get_by_name ~name in
  match existing with Some tag -> Ok tag | None -> create ~name

let list_all () =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.collect_list list_all_query ())
    pool
  |> Result.map (List.map tuple_to_tag)

let list ~page ~per_page () =
  let open Result.Syntax in
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  let* total =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find count_query ())
      pool
  in
  let+ rows =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) ->
        Db.collect_list list_query (per_page, offset))
      pool
  in
  let data = List.map tuple_to_tag rows in
  Model.Shared.Paginated.make ~data ~page ~per_page ~total

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

let add_to_person ~person_id ~tag_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec add_to_person_query (person_id, tag_id))
    pool

let remove_from_person ~person_id ~tag_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec remove_from_person_query (person_id, tag_id))
    pool

let get_by_person ~person_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.collect_list get_by_person_query person_id)
    pool
  |> Result.map (List.map tuple_to_tag)
