module Error = struct
  type t = Not_found | Database of Caqti_error.t

  let pp fmt = function
    | Not_found -> Format.fprintf fmt "Person not found"
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

let create ~name =
  Db.Person.create ~name |> Result.map_error (fun err -> Error.Database err)

let get ~id =
  match Db.Person.get ~id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some person) -> Ok person

let list ~page ~per_page ?query () =
  Db.Person.list ~page ~per_page ?query ()
  |> Result.map_error (fun err -> Error.Database err)

let list_with_counts ~page ~per_page ?query () =
  Db.Person.list_with_counts ~page ~per_page ?query ()
  |> Result.map_error (fun err -> Error.Database err)

let update ~id ~name =
  match Db.Person.update ~id ~name with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some person) -> Ok person

let delete ~id =
  match Db.Person.delete ~id with
  | Error err -> Error (Error.Database err)
  | Ok false -> Error Error.Not_found
  | Ok true -> Ok ()
