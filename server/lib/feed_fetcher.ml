open Lwt.Syntax

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

(* Convert RSS2 item to our article format *)
let rss2_item_to_article ~feed_id (item : Syndic.Rss2.item) :
    Model.Article.create_input option =
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
  | None -> None (* Skip items without URL *)
  | Some url ->
      Some
        {
          Model.Article.feed_id;
          title;
          url;
          published_at = Option.map ptime_to_string item.pubDate;
          content;
          author = item.author;
          image_url = rss2_enclosure_to_image item.enclosure;
        }

(* Convert Atom entry to our article format *)
let atom_entry_to_article ~feed_id (entry : Syndic.Atom.entry) :
    Model.Article.create_input option =
  (* Get URL from links - prefer alternate, fallback to first link *)
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
      (* Look for image in links with image mime type *)
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
      Some
        {
          Model.Article.feed_id;
          title;
          url;
          published_at =
            (match entry.published with
            | Some p -> Some (ptime_to_string p)
            | None -> Some (ptime_to_string entry.updated));
          content;
          author;
          image_url;
        }

(* Fetch URL content *)
let fetch_url (url : string) : (string, string) result Lwt.t =
  Lwt.catch
    (fun () ->
      let* response, body = Cohttp_lwt_unix.Client.get (Uri.of_string url) in
      let status = Cohttp.Response.status response in
      if Cohttp.Code.is_success (Cohttp.Code.code_of_status status) then
        let* body_str = Cohttp_lwt.Body.to_string body in
        Lwt.return_ok body_str
      else
        Lwt.return_error
          (Printf.sprintf "HTTP %d" (Cohttp.Code.code_of_status status)))
    (fun exn ->
      Lwt.return_error
        (Printf.sprintf "Fetch error: %s" (Printexc.to_string exn)))

(* Parse feed content - tries RSS2 first, then Atom *)
type parsed_feed = Rss2 of Syndic.Rss2.channel | Atom of Syndic.Atom.feed

let parse_feed (content : string) : (parsed_feed, string) result =
  let input = Xmlm.make_input (`String (0, content)) in
  try Ok (Rss2 (Syndic.Rss2.parse input))
  with _ -> (
    (* Reset input and try Atom *)
    let input = Xmlm.make_input (`String (0, content)) in
    try Ok (Atom (Syndic.Atom.parse input))
    with exn ->
      Error (Printf.sprintf "Parse error: %s" (Printexc.to_string exn)))

(* Feed metadata for import - author and title extraction *)
type feed_metadata = { author : string option; title : string option }

(* Extract author from RSS2 channel *)
let extract_rss2_author (channel : Syndic.Rss2.channel) : string option =
  (* Try managingEditor first, then look at first item's author *)
  match channel.managingEditor with
  | Some editor -> Some editor
  | None -> (
      match channel.items with
      | item :: _ -> item.author
      | [] -> None)

(* Extract author from Atom feed *)
let extract_atom_author (feed : Syndic.Atom.feed) : string option =
  match feed.authors with
  | author :: _ -> Some author.name
  | [] -> (
      (* Try first entry's author *)
      match feed.entries with
      | entry :: _ ->
          let first_author, _ = entry.authors in
          Some first_author.name
      | [] -> None)

(* Extract feed title *)
let extract_feed_title (feed : parsed_feed) : string option =
  match feed with
  | Rss2 channel -> Some channel.title
  | Atom feed -> (
      match feed.title with
      | Syndic.Atom.Text t -> Some t
      | Syndic.Atom.Html (_, t) -> Some t
      | Syndic.Atom.Xhtml _ -> None)

(* Extract metadata from parsed feed *)
let extract_metadata (feed : parsed_feed) : feed_metadata =
  let author =
    match feed with
    | Rss2 channel -> extract_rss2_author channel
    | Atom feed -> extract_atom_author feed
  in
  let title = extract_feed_title feed in
  { author; title }

(* Fetch feed and extract metadata only - for OPML import *)
let fetch_feed_metadata (url : string) : (feed_metadata, string) result Lwt.t =
  let* fetch_result = fetch_url url in
  match fetch_result with
  | Error msg -> Lwt.return_error msg
  | Ok content -> (
      match parse_feed content with
      | Error msg -> Lwt.return_error msg
      | Ok parsed_feed -> Lwt.return_ok (extract_metadata parsed_feed))

(* Extract articles from parsed feed *)
let extract_articles ~feed_id (feed : parsed_feed) :
    Model.Article.create_input list =
  match feed with
  | Rss2 channel ->
      List.filter_map (rss2_item_to_article ~feed_id) channel.items
  | Atom feed -> List.filter_map (atom_entry_to_article ~feed_id) feed.entries

(* Process a single feed: fetch, parse, store articles *)
let process_feed (feed : Model.Rss_feed.t) : unit Lwt.t =
  Dream.info (fun log -> log "Fetching feed %d: %s" feed.id feed.url);
  let* fetch_result = fetch_url feed.url in
  match fetch_result with
  | Error msg ->
      Dream.error (fun log ->
          log "Failed to fetch feed %d (%s): %s" feed.id feed.url msg);
      Lwt.return_unit
  | Ok content -> (
      match parse_feed content with
      | Error msg ->
          Dream.error (fun log ->
              log "Failed to parse feed %d (%s): %s" feed.id feed.url msg);
          Lwt.return_unit
      | Ok parsed_feed ->
          let articles = extract_articles ~feed_id:feed.id parsed_feed in
          let* insert_result = Db.Article.upsert_many articles in
          (match insert_result with
          | Error msg ->
              Dream.error (fun log ->
                  log "Failed to store articles for feed %d: %s" feed.id msg)
          | Ok count ->
              Dream.info (fun log ->
                  log "Processed %d articles for feed %d" count feed.id));
          (* Update last_fetched_at on the feed *)
          let* _ = Db.Rss_feed.update_last_fetched ~id:feed.id in
          Lwt.return_unit)

(* Fetch all feeds - called by scheduler *)
let fetch_all_feeds () : unit Lwt.t =
  Dream.info (fun log -> log "Starting scheduled feed fetch");
  let* result = Db.Rss_feed.list_all () in
  match result with
  | Error msg ->
      Dream.error (fun log -> log "Failed to list feeds: %s" msg);
      Lwt.return_unit
  | Ok feeds ->
      (* Process feeds sequentially to avoid overwhelming the system *)
      let* () = Lwt_list.iter_s process_feed feeds in
      Dream.info (fun log ->
          log "Completed scheduled feed fetch (%d feeds)" (List.length feeds));
      Lwt.return_unit
