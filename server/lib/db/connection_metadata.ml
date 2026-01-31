let row_type = Caqti_type.(t4 int int int string)

let insert_query =
  Caqti_request.Infix.(Caqti_type.(t3 int int string) ->! Caqti_type.int)
    "INSERT INTO connection_metadata (connection_id, field_type_id, value) VALUES (?, \
     ?, ?) RETURNING id"

let get_query =
  Caqti_request.Infix.(Caqti_type.int ->? row_type)
    "SELECT id, connection_id, field_type_id, value FROM connection_metadata WHERE id \
     = ?"

let list_by_connection_query =
  Caqti_request.Infix.(Caqti_type.int ->* row_type)
    {|
      SELECT cm.id, cm.connection_id, cm.field_type_id, cm.value
      FROM connection_metadata cm
      JOIN metadata_field_types mft ON mft.id = cm.field_type_id
      WHERE cm.connection_id = ?
      ORDER BY mft.name ASC
    |}

let update_query =
  Caqti_request.Infix.(Caqti_type.(t2 string int) ->. Caqti_type.unit)
    "UPDATE connection_metadata SET value = ? WHERE id = ?"

let delete_query =
  Caqti_request.Infix.(Caqti_type.int ->. Caqti_type.unit)
    "DELETE FROM connection_metadata WHERE id = ?"

let exists_query =
  Caqti_request.Infix.(Caqti_type.int ->! Caqti_type.int)
    "SELECT COUNT(*) FROM connection_metadata WHERE id = ?"

let get_with_connection_check_query =
  Caqti_request.Infix.(Caqti_type.(t2 int int) ->? row_type)
    "SELECT id, connection_id, field_type_id, value FROM connection_metadata WHERE id \
     = ? AND connection_id = ?"

let find_existing_query =
  Caqti_request.Infix.(Caqti_type.(t3 int int string) ->? row_type)
    "SELECT id, connection_id, field_type_id, value FROM connection_metadata WHERE \
     connection_id = ? AND field_type_id = ? AND LOWER(TRIM(value)) = LOWER(TRIM(?))"

let tuple_to_metadata (id, connection_id, field_type_id, value) =
  match Model.Metadata_field_type.of_id field_type_id with
  | Some field_type ->
      Some (Model.Connection_metadata.create ~id ~connection_id ~field_type ~value)
  | None -> None

type create_error = [ `Invalid_field_type | `Caqti of Caqti_error.t ]

let find_existing ~connection_id ~field_type_id ~value =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.find_opt find_existing_query (connection_id, field_type_id, value))
    pool
  |> Result.map (fun opt -> Option.bind opt tuple_to_metadata)

let create ~connection_id ~field_type_id ~value =
  let pool = Pool.get () in
  match Model.Metadata_field_type.of_id field_type_id with
  | None -> Error `Invalid_field_type
  | Some field_type -> (
      match find_existing ~connection_id ~field_type_id ~value with
      | Error e -> Error (`Caqti e)
      | Ok (Some existing) -> Ok existing
      | Ok None -> (
          let result =
            Caqti_eio.Pool.use
              (fun (module Db : Caqti_eio.CONNECTION) ->
                Db.find insert_query (connection_id, field_type_id, value))
              pool
          in
          match result with
          | Error e -> Error (`Caqti e)
          | Ok id ->
              Ok
                (Model.Connection_metadata.create ~id ~connection_id ~field_type ~value))
      )

let get ~id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
    pool
  |> Result.map (fun opt -> Option.bind opt tuple_to_metadata)

let get_for_connection ~id ~connection_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.find_opt get_with_connection_check_query (id, connection_id))
    pool
  |> Result.map (fun opt -> Option.bind opt tuple_to_metadata)

let list_by_connection ~connection_id =
  let pool = Pool.get () in
  Caqti_eio.Pool.use
    (fun (module Db : Caqti_eio.CONNECTION) ->
      Db.collect_list list_by_connection_query connection_id)
    pool
  |> Result.map (List.filter_map tuple_to_metadata)

let update ~id ~value =
  let open Result.Syntax in
  let pool = Pool.get () in
  let* existing =
    Caqti_eio.Pool.use
      (fun (module Db : Caqti_eio.CONNECTION) -> Db.find_opt get_query id)
      pool
  in
  match existing with
  | None -> Ok None
  | Some (_, connection_id, field_type_id, _) -> (
      let* () =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) ->
            Db.exec update_query (value, id))
          pool
      in
      match Model.Metadata_field_type.of_id field_type_id with
      | Some field_type ->
          Ok
            (Some
               (Model.Connection_metadata.create ~id ~connection_id ~field_type ~value))
      | None -> Ok None)

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

let delete_for_connection ~id ~connection_id =
  let open Result.Syntax in
  let pool = Pool.get () in
  let* existing = get_for_connection ~id ~connection_id in
  match existing with
  | None -> Ok false
  | Some _ ->
      let+ () =
        Caqti_eio.Pool.use
          (fun (module Db : Caqti_eio.CONNECTION) -> Db.exec delete_query id)
          pool
      in
      true
