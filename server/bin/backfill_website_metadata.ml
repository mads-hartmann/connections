(* One-off script to backfill website metadata from RSS feed URLs.
   For each person with feeds but no Website metadata, extracts the root URL
   from their first feed and adds it as Website metadata. *)

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

let has_website_metadata metadata =
  List.exists
    (fun m ->
      Model.Metadata_field_type.equal
        (Model.Person_metadata.field_type m)
        Model.Metadata_field_type.Website)
    metadata

let process_person person =
  let person_id = Model.Person.id person in
  let name = Model.Person.name person in
  let metadata = Model.Person.metadata person in
  if has_website_metadata metadata then (
    Log.info (fun m -> m "Skipping %s (id=%d): already has website" name person_id);
    Ok `Skipped)
  else
    match Db.Rss_feed.list_by_person ~person_id ~page:1 ~per_page:1 with
    | Error e ->
        Log.err (fun m ->
            m "Error fetching feeds for %s (id=%d): %a" name person_id
              Caqti_error.pp e);
        Error e
    | Ok paginated -> (
        let feeds = paginated.Model.Shared.Paginated.data in
        match feeds with
        | [] ->
            Log.info (fun m -> m "Skipping %s (id=%d): no feeds" name person_id);
            Ok `Skipped
        | feed :: _ -> (
            let feed_url = Model.Rss_feed.url feed in
            match extract_root_url feed_url with
            | None ->
                Log.warn (fun m ->
                    m "Could not extract root URL from %s for %s (id=%d)" feed_url
                      name person_id);
                Ok `Skipped
            | Some root_url -> (
                let field_type_id = Model.Metadata_field_type.id Model.Metadata_field_type.Website in
                match Db.Person_metadata.create ~person_id ~field_type_id ~value:root_url with
                | Error `Invalid_field_type ->
                    Log.err (fun m -> m "Invalid field type for %s (id=%d)" name person_id);
                    Ok `Skipped
                | Error (`Caqti e) ->
                    Log.err (fun m ->
                        m "Error creating metadata for %s (id=%d): %a" name person_id
                          Caqti_error.pp e);
                    Error e
                | Ok _ ->
                    Log.info (fun m ->
                        m "Added website %s for %s (id=%d)" root_url name person_id);
                    Ok `Updated)))

let run db_path dry_run =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level (Some Logs.Info);
  Logs.set_reporter (Logs_fmt.reporter ());
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  Db.Pool.init ~sw ~stdenv:env db_path;
  Db.Pool.apply_schema ();
  Log.info (fun m ->
      m "Starting backfill%s with database %s"
        (if dry_run then " (dry run)" else "")
        db_path);
  (* Fetch all persons with metadata *)
  match Db.Person.list ~page:1 ~per_page:10000 () with
  | Error e ->
      Log.err (fun m -> m "Error fetching persons: %a" Caqti_error.pp e)
  | Ok paginated ->
      let persons = paginated.Model.Shared.Paginated.data in
      (* Fetch metadata for each person *)
      let persons_with_metadata =
        List.filter_map
          (fun person ->
            match Db.Person_metadata.list_by_person ~person_id:(Model.Person.id person) with
            | Error _ -> None
            | Ok metadata -> Some (Model.Person.with_metadata person metadata))
          persons
      in
      let updated = ref 0 in
      let skipped = ref 0 in
      List.iter
        (fun person ->
          if dry_run then (
            let person_id = Model.Person.id person in
            let name = Model.Person.name person in
            let metadata = Model.Person.metadata person in
            if has_website_metadata metadata then
              Log.info (fun m -> m "[DRY RUN] Would skip %s (id=%d): already has website" name person_id)
            else
              match Db.Rss_feed.list_by_person ~person_id ~page:1 ~per_page:1 with
              | Error _ -> ()
              | Ok paginated -> (
                  match paginated.Model.Shared.Paginated.data with
                  | [] ->
                      Log.info (fun m -> m "[DRY RUN] Would skip %s (id=%d): no feeds" name person_id)
                  | feed :: _ -> (
                      match extract_root_url (Model.Rss_feed.url feed) with
                      | None -> ()
                      | Some root_url ->
                          Log.info (fun m ->
                              m "[DRY RUN] Would add website %s for %s (id=%d)" root_url name person_id);
                          incr updated)))
          else
            match process_person person with
            | Ok `Updated -> incr updated
            | Ok `Skipped -> incr skipped
            | Error _ -> incr skipped)
        persons_with_metadata;
      Log.info (fun m ->
          m "Backfill complete: %d updated, %d skipped" !updated !skipped)

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
  let doc = "Backfill website metadata from RSS feed URLs" in
  let info = Cmd.info "backfill-website-metadata" ~doc in
  Cmd.v info Term.(const run $ db_path $ dry_run)

let () = Cmd.eval cmd |> exit
