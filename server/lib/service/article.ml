(* Domain-specific errors *)
module Error = struct
  type t = Not_found | Already_exists | Database of Caqti_error.t

  let pp fmt = function
    | Not_found -> Format.fprintf fmt "Article not found"
    | Already_exists -> Format.fprintf fmt "Article with this URL already exists"
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

(* Domain operations *)

let get ~id =
  match Db.Article.get ~id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some article) -> Ok article

let get_by_url ~url =
  Db.Article.get_by_url ~url |> Result.map_error (fun err -> Error.Database err)

type create_input = {
  url : string;
  person_id : int option;
  title : string option;
  published_at : string option;
  content : string option;
  author : string option;
  image_url : string option;
}

let is_unique_constraint_error err =
  let err_str = Caqti_error.show err in
  let pattern = Str.regexp_string "UNIQUE constraint" in
  (try ignore (Str.search_forward pattern err_str 0); true
   with Not_found -> false)

let create input =
  let open Result.Syntax in
  (* Check if article with this URL already exists *)
  let* existing = get_by_url ~url:input.url in
  match existing with
  | Some _ -> Error Error.Already_exists
  | None ->
      let db_input : Db.Article.create_input =
        {
          feed_id = None;
          person_id = input.person_id;
          title = input.title;
          url = input.url;
          published_at = input.published_at;
          content = input.content;
          author = input.author;
          image_url = input.image_url;
        }
      in
      (* Handle race condition: feed sync might have inserted the article
         between our check and insert *)
      (match Db.Article.create db_input with
      | Ok article -> Ok article
      | Error err when is_unique_constraint_error err ->
          Error Error.Already_exists
      | Error err -> Error (Error.Database err))

let list_all ~page ~per_page ~unread_only ~read_later_only ~tag ?query () =
  match tag with
  | Some tag_name ->
      Db.Article.list_by_tag ~tag:tag_name ~page ~per_page ~unread_only
      |> Result.map_error (fun err -> Error.Database err)
  | None ->
      Db.Article.list_all ~page ~per_page ~unread_only ~read_later_only ?query ()
      |> Result.map_error (fun err -> Error.Database err)

let list_by_feed ~feed_id ~page ~per_page =
  Db.Article.list_by_feed ~feed_id ~page ~per_page
  |> Result.map_error (fun err -> Error.Database err)

let list_by_person ~person_id ~page ~per_page ~unread_only =
  Db.Article.list_by_person ~person_id ~page ~per_page ~unread_only
  |> Result.map_error (fun err -> Error.Database err)

let mark_read ~id ~read =
  match Db.Article.mark_read ~id ~read with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Not_found
  | Ok (Some article) -> Ok article

let mark_read_later ~id ~read_later =
  match Db.Article.mark_read_later ~id ~read_later with
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
