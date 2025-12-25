module Error = struct
  type t = Not_found | Database of Caqti_error.t

  let pp fmt = function
    | Not_found -> Format.fprintf fmt "Tag not found"
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

let create ~name =
  Db.Tag.create ~name |> Result.map_error (fun err -> Error.Database err)

let get ~id =
  match Db.Tag.get ~id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some tag) -> Ok tag

let list ~page ~per_page () =
  Db.Tag.list ~page ~per_page ()
  |> Result.map_error (fun err -> Error.Database err)

let delete ~id =
  match Db.Tag.delete ~id with
  | Error err -> Error (Error.Database err)
  | Ok false -> Error Error.Not_found
  | Ok true -> Ok ()

let add_to_person ~person_id ~tag_id =
  Db.Tag.add_to_person ~person_id ~tag_id
  |> Result.map_error (fun err -> Error.Database err)

let remove_from_person ~person_id ~tag_id =
  Db.Tag.remove_from_person ~person_id ~tag_id
  |> Result.map_error (fun err -> Error.Database err)

let get_by_person ~person_id =
  Db.Tag.get_by_person ~person_id
  |> Result.map_error (fun err -> Error.Database err)

let add_to_feed ~feed_id ~tag_id =
  Db.Tag.add_to_feed ~feed_id ~tag_id
  |> Result.map_error (fun err -> Error.Database err)

let remove_from_feed ~feed_id ~tag_id =
  Db.Tag.remove_from_feed ~feed_id ~tag_id
  |> Result.map_error (fun err -> Error.Database err)

let get_by_feed ~feed_id =
  Db.Tag.get_by_feed ~feed_id
  |> Result.map_error (fun err -> Error.Database err)
