module Error = struct
  type t =
    | Not_found
    | Person_not_found
    | Invalid_field_type
    | Database of Caqti_error.t

  let pp fmt = function
    | Not_found -> Format.fprintf fmt "Metadata not found"
    | Person_not_found -> Format.fprintf fmt "Person not found"
    | Invalid_field_type -> Format.fprintf fmt "Invalid field type"
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

let create ~person_id ~field_type_id ~value =
  (* First verify the person exists *)
  match Db.Person.get ~id:person_id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Person_not_found
  | Ok (Some _) -> (
      match Db.Person_metadata.create ~person_id ~field_type_id ~value with
      | Error `Invalid_field_type -> Error Error.Invalid_field_type
      | Error (`Caqti err) -> Error (Error.Database err)
      | Ok metadata -> Ok metadata)

let get ~id =
  match Db.Person_metadata.get ~id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some metadata) -> Ok metadata

let list_by_person ~person_id =
  Db.Person_metadata.list_by_person ~person_id
  |> Result.map_error (fun err -> Error.Database err)

let update ~id ~person_id ~value =
  (* Verify the metadata belongs to the person *)
  match Db.Person_metadata.get_for_person ~id ~person_id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some _) -> (
      match Db.Person_metadata.update ~id ~value with
      | Error err -> Error (Error.Database err)
      | Ok None -> Error Error.Not_found
      | Ok (Some metadata) -> Ok metadata)

let delete ~id ~person_id =
  match Db.Person_metadata.delete_for_person ~id ~person_id with
  | Error err -> Error (Error.Database err)
  | Ok false -> Error Error.Not_found
  | Ok true -> Ok ()
