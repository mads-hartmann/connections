module Error = struct
  type t = Not_found | Database of Caqti_error.t

  let pp fmt = function
    | Not_found -> Format.fprintf fmt "Feed not found"
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

let create ~connection_id ~url ~title =
  match Db.Rss_feed.create ~connection_id ~url ~title with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some feed) -> Ok feed

let get ~id =
  match Db.Rss_feed.get ~id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some feed) -> Ok feed

let list_by_connection ~connection_id ~page ~per_page =
  Db.Rss_feed.list_by_connection ~connection_id ~page ~per_page
  |> Result.map_error (fun err -> Error.Database err)

let list_all_paginated ~page ~per_page ?query () =
  Db.Rss_feed.list_all_paginated ~page ~per_page ?query ()
  |> Result.map_error (fun err -> Error.Database err)

let update ~id ~url ~title =
  match Db.Rss_feed.update ~id ~url ~title with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some feed) -> Ok feed

let delete ~id =
  match Db.Rss_feed.delete ~id with
  | Error err -> Error (Error.Database err)
  | Ok false -> Error Error.Not_found
  | Ok true -> Ok ()
