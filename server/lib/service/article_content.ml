(* Article content service - read-through cache for markdown content *)

module Error = struct
  type t =
    | Article_not_found
    | Fetch_failed of string
    | Database of Caqti_error.t

  let pp fmt = function
    | Article_not_found -> Format.fprintf fmt "Article not found"
    | Fetch_failed msg -> Format.fprintf fmt "Failed to fetch article: %s" msg
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

let get ~sw ~env ~article_id =
  (* First, get the article to verify it exists and get URL/title *)
  match Db.Article.get ~id:article_id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Article_not_found
  | Ok (Some article) -> (
      (* Check cache first *)
      match Db.Article_content.get_by_article_id ~article_id with
      | Error err -> Error (Error.Database err)
      | Ok (Some (_, markdown)) -> Ok markdown
      | Ok None -> (
          (* Cache miss - fetch and convert *)
          let url = Model.Article.url article in
          let title = Model.Article.title article |> Option.value ~default:"" in
          match Http_client.fetch ~sw ~env url with
          | Error msg -> Error (Error.Fetch_failed msg)
          | Ok html -> (
              let markdown = Html_to_markdown.convert ~title html in
              (* Store in cache *)
              match Db.Article_content.upsert ~article_id ~markdown with
              | Error err -> Error (Error.Database err)
              | Ok () -> Ok markdown)))

let invalidate ~article_id =
  match Db.Article_content.delete_by_article_id ~article_id with
  | Error err -> Error (Error.Database err)
  | Ok () -> Ok ()
