(* One-off script to backfill metadata from RSS feed URLs.
   For each connection with feeds:
   - Adds Website metadata if missing (extracted from feed URL)
   - Fetches the website and extracts photo and social profiles
   - Adds photo if not already set
   - Adds social profiles that don't already exist *)

open Connections_server
module Log = (val Logs.src_log (Logs.Src.create "backfill") : Logs.LOG)

let extract_root_url feed_url =
  let uri = Uri.of_string feed_url in
  match (Uri.scheme uri, Uri.host uri) with
  | Some scheme, Some host ->
      let port_str =
        Option.fold ~none:"" ~some:(fun p -> ":" ^ string_of_int p) (Uri.port uri)
      in
      Some (scheme ^ "://" ^ host ^ port_str)
  | _ -> None

let has_metadata_of_type field_type metadata =
  List.exists
    (fun m ->
      Model.Metadata_field_type.equal (Model.Connection_metadata.field_type m) field_type)
    metadata

let find_website_url metadata =
  List.find_opt
    (fun m ->
      Model.Metadata_field_type.equal
        (Model.Connection_metadata.field_type m)
        Model.Metadata_field_type.Website)
    metadata
  |> Option.map Model.Connection_metadata.value

let add_metadata ~connection_id ~field_type ~value =
  let field_type_id = Model.Metadata_field_type.id field_type in
  match Db.Connection_metadata.create ~connection_id ~field_type_id ~value with
  | Error `Invalid_field_type -> Error "Invalid field type"
  | Error (`Caqti e) -> Error (Format.asprintf "%a" Caqti_error.pp e)
  | Ok _ -> Ok ()

let update_photo ~connection_id ~name ~photo =
  match Db.Connection.update ~id:connection_id ~name ~photo:(Some photo) with
  | Error e -> Error (Format.asprintf "%a" Caqti_error.pp e)
  | Ok None -> Error "Connection not found"
  | Ok (Some _) -> Ok ()

type update_stats = {
  mutable websites_added : int;
  mutable photos_added : int;
  mutable profiles_added : int;
}

let process_connection ~sw ~env ~dry_run ~stats connection =
  let connection_id = Model.Connection.id connection in
  let name = Model.Connection.name connection in
  let metadata = Model.Connection.metadata connection in
  let current_photo = Model.Connection.photo connection in

  (* Step 1: Ensure website metadata exists *)
  let website_url =
    match find_website_url metadata with
    | Some url -> Some url
    | None -> (
        match Db.Rss_feed.list_by_connection ~connection_id ~page:1 ~per_page:1 with
        | Error e ->
            Log.err (fun m ->
                m "Error fetching feeds for %s (id=%d): %a" name connection_id
                  Caqti_error.pp e);
            None
        | Ok paginated -> (
            match paginated.Model.Shared.Paginated.data with
            | [] ->
                Log.debug (fun m -> m "No feeds for %s (id=%d)" name connection_id);
                None
            | feed :: _ -> (
                match extract_root_url (Model.Rss_feed.url feed) with
                | None ->
                    Log.warn (fun m ->
                        m "Could not extract root URL from %s for %s (id=%d)"
                          (Model.Rss_feed.url feed) name connection_id);
                    None
                | Some root_url ->
                    if dry_run then (
                      Log.info (fun m ->
                          m "[DRY RUN] Would add website %s for %s (id=%d)" root_url
                            name connection_id);
                      stats.websites_added <- stats.websites_added + 1;
                      Some root_url)
                    else (
                      match
                        add_metadata ~connection_id
                          ~field_type:Model.Metadata_field_type.Website ~value:root_url
                      with
                      | Error e ->
                          Log.err (fun m ->
                              m "Error adding website for %s (id=%d): %s" name connection_id e);
                          None
                      | Ok () ->
                          Log.info (fun m ->
                              m "Added website %s for %s (id=%d)" root_url name connection_id);
                          stats.websites_added <- stats.websites_added + 1;
                          Some root_url))))
  in

  (* Step 2: Fetch metadata from website if we have a URL *)
  match website_url with
  | None -> ()
  | Some url -> (
      let fetch_with_timeout () =
        Eio.Time.with_timeout_exn (Eio.Stdenv.clock env) 30.0 (fun () ->
            Metadata.Contact.fetch ~sw ~env url)
      in
      match fetch_with_timeout () with
      | exception Eio.Time.Timeout ->
          Log.warn (fun m ->
              m "Timeout fetching metadata from %s for %s (id=%d)" url name connection_id)
      | Error e ->
          Log.warn (fun m ->
              m "Could not fetch metadata from %s for %s (id=%d): %s" url name
                connection_id e)
      | Ok contact ->
          (* Step 3: Add photo if not set *)
          (match (current_photo, contact.photo) with
          | None, Some photo ->
              if dry_run then (
                Log.info (fun m ->
                    m "[DRY RUN] Would add photo for %s (id=%d): %s" name connection_id
                      photo);
                stats.photos_added <- stats.photos_added + 1)
              else (
                match update_photo ~connection_id ~name ~photo with
                | Error e ->
                    Log.err (fun m ->
                        m "Error adding photo for %s (id=%d): %s" name connection_id e)
                | Ok () ->
                    Log.info (fun m ->
                        m "Added photo for %s (id=%d): %s" name connection_id photo);
                    stats.photos_added <- stats.photos_added + 1)
          | Some _, _ ->
              Log.debug (fun m -> m "%s (id=%d) already has photo" name connection_id)
          | None, None ->
              Log.debug (fun m ->
                  m "No photo found for %s (id=%d)" name connection_id));

          (* Step 4: Add social profiles that don't exist *)
          List.iter
            (fun (profile : Metadata.Contact.Classified_profile.t) ->
              let field_type = profile.field_type in
              (* Skip Website and Other types *)
              if
                Model.Metadata_field_type.equal field_type
                  Model.Metadata_field_type.Website
                || Model.Metadata_field_type.equal field_type
                     Model.Metadata_field_type.Other
              then ()
              else if has_metadata_of_type field_type metadata then
                Log.debug (fun m ->
                    m "%s (id=%d) already has %s" name connection_id
                      (Model.Metadata_field_type.name field_type))
              else if dry_run then (
                Log.info (fun m ->
                    m "[DRY RUN] Would add %s for %s (id=%d): %s"
                      (Model.Metadata_field_type.name field_type)
                      name connection_id profile.url);
                stats.profiles_added <- stats.profiles_added + 1)
              else
                match add_metadata ~connection_id ~field_type ~value:profile.url with
                | Error e ->
                    Log.err (fun m ->
                        m "Error adding %s for %s (id=%d): %s"
                          (Model.Metadata_field_type.name field_type)
                          name connection_id e)
                | Ok () ->
                    Log.info (fun m ->
                        m "Added %s for %s (id=%d): %s"
                          (Model.Metadata_field_type.name field_type)
                          name connection_id profile.url);
                    stats.profiles_added <- stats.profiles_added + 1)
            contact.social_profiles)

let run db_path dry_run =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level (Some Logs.Info);
  Logs.set_reporter (Logs_fmt.reporter ());
  (* Silence verbose HTTP logging *)
  let noisy_prefixes = [ "piaf"; "httpun"; "h2"; "gluten"; "ssl" ] in
  List.iter
    (fun src ->
      let name = Logs.Src.name src in
      if List.exists (fun prefix -> String.starts_with ~prefix name) noisy_prefixes
      then Logs.Src.set_level src (Some Logs.Warning))
    (Logs.Src.list ());
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  Db.Pool.init ~sw ~stdenv:env db_path;
  Db.Pool.apply_schema ();
  Log.info (fun m ->
      m "Starting backfill%s with database %s"
        (if dry_run then " (dry run)" else "")
        db_path);
  (* Fetch all connections with metadata *)
  match Db.Connection.list ~page:1 ~per_page:10000 () with
  | Error e ->
      Log.err (fun m -> m "Error fetching connections: %a" Caqti_error.pp e)
  | Ok paginated ->
      let connections = paginated.Model.Shared.Paginated.data in
      (* Fetch metadata for each connection *)
      let connections_with_metadata =
        List.filter_map
          (fun connection ->
            match
              Db.Connection_metadata.list_by_connection ~connection_id:(Model.Connection.id connection)
            with
            | Error _ -> None
            | Ok metadata -> Some (Model.Connection.with_metadata connection metadata))
          connections
      in
      let stats =
        { websites_added = 0; photos_added = 0; profiles_added = 0 }
      in
      List.iter (process_connection ~sw ~env ~dry_run ~stats) connections_with_metadata;
      Log.info (fun m ->
          m "Backfill complete: %d websites, %d photos, %d profiles added"
            stats.websites_added stats.photos_added stats.profiles_added)

open Cmdliner

let db_path =
  let doc = "Path to the SQLite database file." in
  let env = Cmd.Env.info "DB_PATH" in
  Arg.(
    value & opt string "connections.db" & info [ "db" ] ~env ~docv:"PATH" ~doc)

let dry_run =
  let doc = "Show what would be done without making changes." in
  Arg.(value & flag & info [ "dry-run"; "n" ] ~doc)

let cmd =
  let doc = "Backfill metadata (website, photo, social profiles) from RSS feed URLs" in
  let info = Cmd.info "backfill-metadata" ~doc in
  Cmd.v info Term.(const run $ db_path $ dry_run)

let () = Cmd.eval cmd |> exit
