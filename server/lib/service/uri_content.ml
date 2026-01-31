(* URI content service - read-through cache for markdown content *)

module Error = struct
  type t =
    | Uri_not_found
    | Fetch_failed of string
    | Database of Caqti_error.t

  let pp fmt = function
    | Uri_not_found -> Format.fprintf fmt "URI not found"
    | Fetch_failed msg -> Format.fprintf fmt "Failed to fetch URI: %s" msg
    | Database err -> Format.fprintf fmt "Database error: %a" Caqti_error.pp err

  let to_string err = Format.asprintf "%a" pp err
end

let get ~sw ~env ~uri_id =
  (* First, get the URI to verify it exists and get URL/title *)
  match Db.Uri_store.get ~id:uri_id with
  | Error err -> Error (Error.Database err)
  | Ok None -> Error Error.Uri_not_found
  | Ok (Some uri) -> (
      (* Check cache first *)
      match Db.Uri_content.get_by_uri_id ~uri_id with
      | Error err -> Error (Error.Database err)
      | Ok (Some (_, markdown)) -> Ok markdown
      | Ok None -> (
          (* Cache miss - fetch and convert *)
          let url = Model.Uri_entry.url uri in
          let title = Model.Uri_entry.title uri |> Option.value ~default:"" in
          match Http_client.fetch ~sw ~env url with
          | Error msg -> Error (Error.Fetch_failed msg)
          | Ok html -> (
              let markdown = Html_to_markdown.convert ~title html in
              (* Store in cache *)
              match Db.Uri_content.upsert ~uri_id ~markdown with
              | Error err -> Error (Error.Database err)
              | Ok () -> Ok markdown)))

let invalidate ~uri_id =
  match Db.Uri_content.delete_by_uri_id ~uri_id with
  | Error err -> Error (Error.Database err)
  | Ok () -> Ok ()
