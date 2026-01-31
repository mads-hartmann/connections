module Error = struct
  type t =
    | Not_found
    | Connection_not_found
    | Invalid_field_type
    | Database of Caqti_error.t

  let pp fmt = function
    | Not_found -> Format.fprintf fmt "Metadata not found"
    | Connection_not_found -> Format.fprintf fmt "Connection not found"
    | Invalid_field_type -> Format.fprintf fmt "Invalid field type"
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

let create ~connection_id ~field_type_id ~value =
  (* First verify the connection exists *)
  match Db.Connection.get ~id:connection_id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Connection_not_found
  | Ok (Some _) -> (
      match Db.Connection_metadata.create ~connection_id ~field_type_id ~value with
      | Error `Invalid_field_type -> Error Error.Invalid_field_type
      | Error (`Caqti err) -> Error (Error.Database err)
      | Ok metadata -> Ok metadata)

let get ~id =
  match Db.Connection_metadata.get ~id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some metadata) -> Ok metadata

let list_by_connection ~connection_id =
  Db.Connection_metadata.list_by_connection ~connection_id
  |> Result.map_error (fun err -> Error.Database err)

let update ~id ~connection_id ~value =
  (* Verify the metadata belongs to the connection *)
  match Db.Connection_metadata.get_for_connection ~id ~connection_id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some _) -> (
      match Db.Connection_metadata.update ~id ~value with
      | Error err -> Error (Error.Database err)
      | Ok None -> Error Error.Not_found
      | Ok (Some metadata) -> Ok metadata)

let delete ~id ~connection_id =
  match Db.Connection_metadata.delete_for_connection ~id ~connection_id with
  | Error err -> Error (Error.Database err)
  | Ok false -> Error Error.Not_found
  | Ok true -> Ok ()
