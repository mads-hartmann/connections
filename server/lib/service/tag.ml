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

let list ~page ~per_page ?query () =
  Db.Tag.list ~page ~per_page ?query ()
  |> Result.map_error (fun err -> Error.Database err)

let delete ~id =
  match Db.Tag.delete ~id with
  | Error err -> Error (Error.Database err)
  | Ok false -> Error Error.Not_found
  | Ok true -> Ok ()

let update ~id ~name =
  match Db.Tag.update ~id ~name with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some tag) -> Ok tag

let add_to_connection ~connection_id ~tag_id =
  Db.Tag.add_to_connection ~connection_id ~tag_id
  |> Result.map_error (fun err -> Error.Database err)

let remove_from_connection ~connection_id ~tag_id =
  Db.Tag.remove_from_connection ~connection_id ~tag_id
  |> Result.map_error (fun err -> Error.Database err)

let get_by_connection ~connection_id =
  Db.Tag.get_by_connection ~connection_id
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

let add_to_uri ~uri_id ~tag_id =
  Db.Tag.add_to_uri ~uri_id ~tag_id
  |> Result.map_error (fun err -> Error.Database err)

let remove_from_uri ~uri_id ~tag_id =
  Db.Tag.remove_from_uri ~uri_id ~tag_id
  |> Result.map_error (fun err -> Error.Database err)

let get_by_uri ~uri_id =
  Db.Tag.get_by_uri ~uri_id
  |> Result.map_error (fun err -> Error.Database err)
