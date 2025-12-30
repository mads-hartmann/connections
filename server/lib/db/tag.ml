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

let list_filtered_query =
  Caqti_request.Infix.(Caqti_type.(t3 string int int) ->* tag_row_type)
    "SELECT id, name FROM tags WHERE name LIKE ? ORDER BY name LIMIT ? OFFSET ?"

let count_filtered_query =
  Caqti_request.Infix.(Caqti_type.string ->! Caqti_type.int)
    "SELECT COUNT(*) FROM tags WHERE name LIKE ?"

let delete_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "DELETE FROM tags WHERE id = ?"

let update_query =
  Caqti_request.Infix.(Caqti_type.(t2 string int) ->. Caqti_type.unit)
    "UPDATE tags SET name = ? WHERE id = ?"

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

let tuple_to_tag (id, name) = Model.Tag.create ~id ~name

let create ~name =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.find insert_query name)
    pool
  |> Result.map (fun id -> Model.Tag.create ~id ~name)

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

let list ~page ~per_page ?query () =
  let open Result.Syntax in
  let pool = Pool.get () in
  let offset = (page - 1) * per_page in
  match query with
  | None ->
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
  | Some q ->
      let pattern = "%" ^ q ^ "%" in
      let* total =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.find count_filtered_query pattern)
          pool
      in
      let+ rows =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.collect_list list_filtered_query (pattern, per_page, offset))
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
      Some (Model.Tag.create ~id ~name)

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

(* Feed-Tag associations *)
let add_to_feed_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->. Caqti_type.unit)
    "INSERT OR IGNORE INTO feed_tags (feed_id, tag_id) VALUES (?, ?)"

let remove_from_feed_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->. Caqti_type.unit)
    "DELETE FROM feed_tags WHERE feed_id = ? AND tag_id = ?"

let get_by_feed_query =
  Caqti_request.Infix.(Caqti_type.int ->* tag_row_type)
    "SELECT t.id, t.name FROM tags t INNER JOIN feed_tags ft ON t.id = \
     ft.tag_id WHERE ft.feed_id = ? ORDER BY t.name"

let add_to_feed ~feed_id ~tag_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec add_to_feed_query (feed_id, tag_id))
    pool

let remove_from_feed ~feed_id ~tag_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec remove_from_feed_query (feed_id, tag_id))
    pool

let get_by_feed ~feed_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.collect_list get_by_feed_query feed_id)
    pool
  |> Result.map (List.map tuple_to_tag)

(* Article-Tag associations *)
let add_to_article_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->. Caqti_type.unit)
    "INSERT OR IGNORE INTO article_tags (article_id, tag_id) VALUES (?, ?)"

let remove_from_article_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->. Caqti_type.unit)
    "DELETE FROM article_tags WHERE article_id = ? AND tag_id = ?"

let get_by_article_query =
  Caqti_request.Infix.(Caqti_type.int ->* tag_row_type)
    "SELECT t.id, t.name FROM tags t INNER JOIN article_tags at ON t.id = \
     at.tag_id WHERE at.article_id = ? ORDER BY t.name"

let add_to_article ~article_id ~tag_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec add_to_article_query (article_id, tag_id))
    pool

let remove_from_article ~article_id ~tag_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.exec remove_from_article_query (article_id, tag_id))
    pool

let get_by_article ~article_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.collect_list get_by_article_query article_id)
    pool
  |> Result.map (List.map tuple_to_tag)
