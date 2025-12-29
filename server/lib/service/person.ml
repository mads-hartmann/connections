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

(* Profile image resolution with priority: u-photo > gravatar > favicon *)
let resolve_profile_image ~sw ~env ~(metadata : Url_metadata.t) =
  let author_photo = Option.bind metadata.author (fun a -> a.photo) in
  match author_photo with
  | Some url -> Some url
  | None ->
      let email = Option.bind metadata.author (fun a -> a.email) in
      let gravatar = Option.bind email (Url_metadata.Gravatar.validate ~sw ~env) in
      (match gravatar with
      | Some url -> Some url
      | None -> metadata.site.favicon)

let find_website_url ~(person : Model.Person.t) =
  List.find_map
    (fun (m : Model.Person_metadata.t) ->
      match m.field_type with
      | Model.Metadata_field_type.Website -> Some m.value
      | _ -> None)
    person.metadata

let current_timestamp () =
  let now = Unix.gettimeofday () in
  let tm = Unix.gmtime now in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
    (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec

let refresh_metadata ~sw ~env ~id =
  let open Result.Syntax in
  let* person = get ~id in
  match find_website_url ~person with
  | None ->
      (* No website, just update timestamp *)
      let timestamp = current_timestamp () in
      let+ () =
        Db.Person.update_profile_image ~id ~profile_image_url:None
          ~metadata_updated_at:timestamp
        |> Result.map_error (fun err -> Error.Database err)
      in
      { person with metadata_updated_at = Some timestamp }
  | Some website_url -> (
      match Url_metadata.fetch ~sw ~env website_url with
      | Error _ ->
          (* Fetch failed, update timestamp only *)
          let timestamp = current_timestamp () in
          let+ () =
            Db.Person.update_profile_image ~id ~profile_image_url:None
              ~metadata_updated_at:timestamp
            |> Result.map_error (fun err -> Error.Database err)
          in
          { person with metadata_updated_at = Some timestamp }
      | Ok metadata ->
          let profile_image_url = resolve_profile_image ~sw ~env ~metadata in
          let timestamp = current_timestamp () in
          let+ () =
            Db.Person.update_profile_image ~id ~profile_image_url
              ~metadata_updated_at:timestamp
            |> Result.map_error (fun err -> Error.Database err)
          in
          {
            person with
            profile_image_url;
            metadata_updated_at = Some timestamp;
          })

let list_needing_metadata_refresh ~older_than ~limit =
  Db.Person.list_needing_metadata_refresh ~older_than ~limit
  |> Result.map_error (fun err -> Error.Database err)
