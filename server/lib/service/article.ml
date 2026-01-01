(* Domain-specific errors *)
module Error = struct
  type t = Not_found | Database of Caqti_error.t

  let pp fmt = function
    | Not_found -> Format.fprintf fmt "Article not found"
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

(* Domain operations *)

let get ~id =
  match Db.Article.get ~id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some article) -> Ok article

let list_all ~page ~per_page ~unread_only ~tag ?query () =
  match tag with
  | Some tag_name ->
      Db.Article.list_by_tag ~tag:tag_name ~page ~per_page ~unread_only
      |> Result.map_error (fun err -> Error.Database err)
  | None ->
      Db.Article.list_all ~page ~per_page ~unread_only ?query ()
      |> Result.map_error (fun err -> Error.Database err)

let list_by_feed ~feed_id ~page ~per_page =
  Db.Article.list_by_feed ~feed_id ~page ~per_page
  |> Result.map_error (fun err -> Error.Database err)

let mark_read ~id ~read =
  match Db.Article.mark_read ~id ~read with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some article) -> Ok article

let mark_all_read ~feed_id =
  Db.Article.mark_all_read ~feed_id
  |> Result.map_error (fun err -> Error.Database err)

let mark_all_read_global () =
  Db.Article.mark_all_read_global ()
  |> Result.map_error (fun err -> Error.Database err)

let delete ~id =
  match Db.Article.delete ~id with
  | Error err -> Error (Error.Database err)
  | Ok false -> Error Error.Not_found
  | Ok true -> Ok ()
