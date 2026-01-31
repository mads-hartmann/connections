(* Domain-specific errors *)
module Error = struct
  type t = Not_found | Database of Caqti_error.t

  let pp fmt = function
    | Not_found -> Format.fprintf fmt "URI not found"
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

(* Domain operations *)

let get ~id =
  match Db.Uri_store.get ~id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some uri) -> Ok uri

let create ~connection_id ~kind ~url ~title =
  Db.Uri_store.create ~connection_id ~kind ~url ~title
  |> Result.map_error (fun err -> Error.Database err)

let update ~id ~connection_id ~kind ~title =
  match Db.Uri_store.update ~id ~connection_id ~kind ~title with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some uri) -> Ok uri

let list_all ~page ~per_page ~unread_only ~read_later_only ~tag ~orphan_only ?query () =
  Db.Uri_store.list_all ~page ~per_page ~unread_only ~read_later_only ~tag ~orphan_only ?query ()
  |> Result.map_error (fun err -> Error.Database err)

let list_by_feed ~feed_id ~page ~per_page =
  Db.Uri_store.list_by_feed ~feed_id ~page ~per_page
  |> Result.map_error (fun err -> Error.Database err)

let list_by_connection ~connection_id ~page ~per_page ~unread_only =
  Db.Uri_store.list_by_connection ~connection_id ~page ~per_page ~unread_only
  |> Result.map_error (fun err -> Error.Database err)

let mark_read ~id ~read =
  match Db.Uri_store.mark_read ~id ~read with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some uri) -> Ok uri

let mark_read_later ~id ~read_later =
  match Db.Uri_store.mark_read_later ~id ~read_later with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some uri) -> Ok uri

let mark_all_read ~feed_id =
  Db.Uri_store.mark_all_read ~feed_id
  |> Result.map_error (fun err -> Error.Database err)

let mark_all_read_global () =
  Db.Uri_store.mark_all_read_global ()
  |> Result.map_error (fun err -> Error.Database err)

let mark_all_read_by_connection ~connection_id =
  Db.Uri_store.mark_all_read_by_connection ~connection_id
  |> Result.map_error (fun err -> Error.Database err)

let delete ~id =
  match Db.Uri_store.delete ~id with
  | Error err -> Error (Error.Database err)
  | Ok false -> Error Error.Not_found
  | Ok true -> Ok ()
