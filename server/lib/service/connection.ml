module Error = struct
  type t = Not_found | Database of Caqti_error.t

  let pp fmt = function
    | Not_found -> Format.fprintf fmt "Connection not found"
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

let create ~name ?photo () =
  Db.Connection.create ~name ?photo () |> Result.map_error (fun err -> Error.Database err)

let get ~id =
  match Db.Connection.get ~id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some connection) -> Ok connection

let list ~page ~per_page ?query () =
  Db.Connection.list ~page ~per_page ?query ()
  |> Result.map_error (fun err -> Error.Database err)

let list_with_counts ~page ~per_page ?query () =
  Db.Connection.list_with_counts ~page ~per_page ?query ()
  |> Result.map_error (fun err -> Error.Database err)

let update ~id ~name ~photo =
  match Db.Connection.update ~id ~name ~photo with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some connection) -> Ok connection

let delete ~id =
  match Db.Connection.delete ~id with
  | Error err -> Error (Error.Database err)
  | Ok false -> Error Error.Not_found
  | Ok true -> Ok ()
