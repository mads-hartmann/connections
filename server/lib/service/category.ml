module Error = struct
  type t = Not_found | Database of Caqti_error.t

  let pp fmt = function
    | Not_found -> Format.fprintf fmt "Category not found"
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

let create ~name =
  Db.Category.create ~name |> Result.map_error (fun err -> Error.Database err)

let get ~id =
  match Db.Category.get ~id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some category) -> Ok category

let list ~page ~per_page () =
  Db.Category.list ~page ~per_page ()
  |> Result.map_error (fun err -> Error.Database err)

let delete ~id =
  match Db.Category.delete ~id with
  | Error err -> Error (Error.Database err)
  | Ok false -> Error Error.Not_found
  | Ok true -> Ok ()

let add_to_person ~person_id ~category_id =
  Db.Category.add_to_person ~person_id ~category_id
  |> Result.map_error (fun err -> Error.Database err)

let remove_from_person ~person_id ~category_id =
  Db.Category.remove_from_person ~person_id ~category_id
  |> Result.map_error (fun err -> Error.Database err)

let get_by_person ~person_id =
  Db.Category.get_by_person ~person_id
  |> Result.map_error (fun err -> Error.Database err)
