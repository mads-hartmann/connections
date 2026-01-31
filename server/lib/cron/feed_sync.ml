(** Scheduled RSS/Atom feed synchronization. *)

module Log = (val Logs.src_log (Logs.Src.create "cron.feed_sync") : Logs.LOG)

let fetch_interval_seconds = 3600.0 (* 1 hour *)

(* Format a Ptime to SQLite datetime string *)
let ptime_to_string (ptime : Ptime.t) : string =
  let (y, m, d), ((hh, mm, ss), _tz) = Ptime.to_date_time ptime in
  Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d" y m d hh mm ss

(* Extract text from Syndic RSS2 story *)
let rss2_story_to_title_and_content (story : Syndic.Rss2.story) :
    string option * string option =
  match story with
  | Syndic.Rss2.All (title, _, description) -> (Some title, Some description)
  | Syndic.Rss2.Title title -> (Some title, None)
  | Syndic.Rss2.Description (_, description) -> (None, Some description)

(* Extract image URL from RSS2 enclosure if it's an image *)
let rss2_enclosure_to_image (enclosure : Syndic.Rss2.enclosure option) :
    string option =
  match enclosure with
  | Some enc ->
      let mime = enc.Syndic.Rss2.mime in
      if String.length mime >= 6 && String.sub mime 0 6 = "image/" then
        Some (Uri.to_string enc.Syndic.Rss2.url)
      else None
  | None -> None

(* Extract category names from RSS2 item *)
let rss2_item_categories (item : Syndic.Rss2.item) : string list =
  List.map (fun (cat : Syndic.Rss2.category) -> cat.data) item.categories

(* Extract category names from Atom entry *)
let atom_entry_categories (entry : Syndic.Atom.entry) : string list =
  List.filter_map
    (fun (cat : Syndic.Atom.category) ->
      match cat.label with Some label -> Some label | None -> Some cat.term)
    entry.categories

type uri_with_tags = {
  feed_id : int;
  connection_id : int option;
  kind : Model.Uri_kind.t;
  title : string option;
  url : string;
  published_at : string option;
  content : string option;
  author : string option;
  image_url : string option;
  tags : string list;
}

(* Convert RSS2 item to URI format with tags *)
let rss2_item_to_uri ~feed_id ~connection_id (item : Syndic.Rss2.item) :
    uri_with_tags option =
  let title, content = rss2_story_to_title_and_content item.story in
  let url =
    match item.link with
    | Some link -> Some (Uri.to_string link)
    | None -> (
        match item.guid with
        | Some guid -> Some (Uri.to_string guid.data)
        | None -> None)
  in
  match url with
  | None -> None
  | Some url ->
      let uri =
        {
          feed_id;
          connection_id;
          kind = Model.Uri_kind.Blog;
          title;
          url;
          published_at = Option.map ptime_to_string item.pubDate;
          content;
          author = item.author;
          image_url = rss2_enclosure_to_image item.enclosure;
          tags = rss2_item_categories item;
        }
      in
      Some uri

(* Convert Atom entry to URI format with tags *)
let atom_entry_to_uri ~feed_id ~connection_id (entry : Syndic.Atom.entry) :
    uri_with_tags option =
  let url =
    let links = entry.links in
    let alternate =
      List.find_opt
        (fun (link : Syndic.Atom.link) -> link.rel = Syndic.Atom.Alternate)
        links
    in
    match alternate with
    | Some link -> Some (Uri.to_string link.href)
    | None -> (
        match links with
        | link :: _ -> Some (Uri.to_string link.href)
        | [] -> Some (Uri.to_string entry.id))
  in
  match url with
  | None -> None
  | Some url ->
      let title =
        match entry.title with
        | Syndic.Atom.Text t -> Some t
        | Syndic.Atom.Html (_, t) -> Some t
        | Syndic.Atom.Xhtml (_, _) -> None
      in
      let content =
        match entry.content with
        | Some (Syndic.Atom.Text t) -> Some t
        | Some (Syndic.Atom.Html (_, t)) -> Some t
        | Some (Syndic.Atom.Xhtml (_, _)) -> None
        | Some (Syndic.Atom.Mime _) -> None
        | Some (Syndic.Atom.Src _) -> None
        | None -> (
            match entry.summary with
            | Some (Syndic.Atom.Text t) -> Some t
            | Some (Syndic.Atom.Html (_, t)) -> Some t
            | Some (Syndic.Atom.Xhtml (_, _)) -> None
            | None -> None)
      in
      let author =
        let first_author, _ = entry.authors in
        Some first_author.name
      in
      let image_url =
        List.find_map
          (fun (link : Syndic.Atom.link) ->
            match link.type_media with
            | Some mime
              when String.length mime >= 6 && String.sub mime 0 6 = "image/" ->
                Some (Uri.to_string link.href)
            | _ -> None)
          entry.links
      in
      let uri =
        {
          feed_id;
          connection_id;
          kind = Model.Uri_kind.Blog;
          title;
          url;
          published_at =
            (match entry.published with
            | Some p -> Some (ptime_to_string p)
            | None -> Some (ptime_to_string entry.updated));
          content;
          author;
          image_url;
          tags = atom_entry_categories entry;
        }
      in
      Some uri

let extract_uris_with_tags ~feed_id ~connection_id
    (feed : Feed_parser.parsed_feed) : uri_with_tags list =
  match feed with
  | Rss2 channel ->
      List.filter_map (rss2_item_to_uri ~feed_id ~connection_id) channel.items
  | Atom feed ->
      List.filter_map (atom_entry_to_uri ~feed_id ~connection_id) feed.entries

let associate_tags_with_uri ~uri_id ~tag_names : unit =
  List.iter
    (fun tag_name ->
      match Db.Tag.get_or_create ~name:tag_name with
      | Error err ->
          Log.err (fun m ->
              m "Failed to get/create tag '%s': %a" tag_name Caqti_error.pp err)
      | Ok tag -> (
          match
            Db.Tag.add_to_uri ~uri_id ~tag_id:(Model.Tag.id tag)
          with
          | Error err ->
              Log.err (fun m ->
                  m "Failed to associate tag '%s' with URI %d: %a" tag_name
                    uri_id Caqti_error.pp err)
          | Ok () -> ()))
    tag_names

let get_feed_tag_ids ~feed_id : int list =
  match Db.Tag.get_by_feed ~feed_id with
  | Error _ -> []
  | Ok tags -> List.map Model.Tag.id tags

let process_feed ~sw ~env (feed : Model.Rss_feed.t) : unit =
  let feed_id = Model.Rss_feed.id feed in
  let feed_url = Model.Rss_feed.url feed in
  let connection_id = Some (Model.Rss_feed.connection_id feed) in
  Log.info (fun m -> m "Fetching feed %d: %s" feed_id feed_url);
  match Http_client.fetch ~sw ~env feed_url with
  | Error msg ->
      Log.err (fun m ->
          m "Failed to fetch feed %d (%s): %s" feed_id feed_url msg)
  | Ok content -> (
      match Feed_parser.parse content with
      | Error msg ->
          Log.err (fun m ->
              m "Failed to parse feed %d (%s): %s" feed_id feed_url msg)
      | Ok parsed_feed ->
          let uris_with_tags =
            extract_uris_with_tags ~feed_id ~connection_id parsed_feed
          in
          let feed_tag_ids = get_feed_tag_ids ~feed_id in
          let count = ref 0 in
          List.iter
            (fun uri_data ->
              match Db.Uri_store.upsert ~feed_id:uri_data.feed_id
                      ~connection_id:uri_data.connection_id
                      ~kind:uri_data.kind ~title:uri_data.title
                      ~url:uri_data.url ~published_at:uri_data.published_at
                      ~content:uri_data.content ~author:uri_data.author
                      ~image_url:uri_data.image_url with
              | Error err ->
                  Log.err (fun m ->
                      m "Failed to upsert URI '%s': %a"
                        (Option.value ~default:uri_data.url uri_data.title)
                        Caqti_error.pp err)
              | Ok stored_uri ->
                  incr count;
                  let stored_id = Model.Uri_entry.id stored_uri in
                  associate_tags_with_uri ~uri_id:stored_id
                    ~tag_names:uri_data.tags;
                  List.iter
                    (fun tag_id ->
                      let _ =
                        Db.Tag.add_to_uri ~uri_id:stored_id ~tag_id
                      in
                      ())
                    feed_tag_ids)
            uris_with_tags;
          Log.info (fun m ->
              m "Processed %d URIs for feed %d" !count feed_id);
          let _ = Db.Rss_feed.update_last_fetched ~id:feed_id in
          ())

let fetch_all_feeds ~sw ~env () : unit =
  Log.info (fun m -> m "Starting scheduled feed sync");
  match Db.Rss_feed.list_all () with
  | Error err ->
      Log.err (fun m -> m "Failed to list feeds: %a" Caqti_error.pp err)
  | Ok feeds ->
      List.iter (process_feed ~sw ~env) feeds;
      Log.info (fun m ->
          m "Completed scheduled feed sync (%d feeds)" (List.length feeds))

let running = ref true
let stop () = running := false

let rec run_loop ~sw ~env ~clock () =
  if not !running then ()
  else (
    (try fetch_all_feeds ~sw ~env ()
     with exn ->
       Log.err (fun m -> m "Feed sync error: %s" (Printexc.to_string exn)));
    let rec interruptible_sleep remaining =
      if (not !running) || remaining <= 0.0 then ()
      else
        let sleep_time = min 1.0 remaining in
        Eio.Time.sleep clock sleep_time;
        interruptible_sleep (remaining -. sleep_time)
    in
    interruptible_sleep fetch_interval_seconds;
    run_loop ~sw ~env ~clock ())

let start ~sw ~env =
  let clock = Eio.Stdenv.clock env in
  Log.info (fun m ->
      m "Starting feed sync (interval: %g seconds)" fetch_interval_seconds);
  running := true;
  Eio.Fiber.fork_daemon ~sw (fun () ->
      Eio.Time.sleep clock 5.0;
      run_loop ~sw ~env ~clock ();
      `Stop_daemon)
