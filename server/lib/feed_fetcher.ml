module Log = (val Logs.src_log (Logs.Src.create "feed_fetcher") : Logs.LOG)

(* Format a Ptime to SQLite datetime string *)
let ptime_to_string (ptime : Ptime.t) : string =
  let (y, m, d), ((hh, mm, ss), _tz) = Ptime.to_date_time ptime in
  Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d" y m d hh mm ss

(* Extract title from RSS2 story *)
let rss2_story_to_title (story : Syndic.Rss2.story) : string option =
  match story with
  | Syndic.Rss2.All (title, _, _) -> Some title
  | Syndic.Rss2.Title title -> Some title
  | Syndic.Rss2.Description _ -> None

(* Extract description from RSS2 story *)
let rss2_story_to_description (story : Syndic.Rss2.story) : string option =
  match story with
  | Syndic.Rss2.All (_, _, description) -> Some description
  | Syndic.Rss2.Title _ -> None
  | Syndic.Rss2.Description (_, description) -> Some description

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

(* Article with extracted tags *)
type article_with_tags = {
  article : Db.Article.create_input;
  tags : string list;
}

(* Convert RSS2 item to our article format with tags.
   RSS2 has:
   - story: contains title and/or description (typically a synopsis, often HTML)
   - content: from content:encoded extension, the full article (HTML)
   
   Strategy:
   - content_html = content:encoded if present, else description
   - summary = description (as text) if content:encoded exists, else generate from content_html *)
let rss2_item_to_article ~feed_id (item : Syndic.Rss2.item) :
    article_with_tags option =
  let title = rss2_story_to_title item.story in
  let description = rss2_story_to_description item.story in
  let content_encoded =
    let _, content_str = item.content in
    if String.length content_str > 0 then Some content_str else None
  in
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
      let content_html =
        match content_encoded with
        | Some c -> Some c
        | None -> description
      in
      let summary =
        match content_encoded with
        | Some _ ->
            (* Have full content, use description as summary *)
            Html_text.to_summary ~html:description ~text:None
        | None ->
            (* No full content, generate summary from description *)
            Html_text.to_summary ~html:content_html ~text:None
      in
      let article =
        {
          Db.Article.feed_id;
          title;
          url;
          published_at = Option.map ptime_to_string item.pubDate;
          content_html;
          summary;
          author = item.author;
          image_url = rss2_enclosure_to_image item.enclosure;
        }
      in
      let tags = rss2_item_categories item in
      Some { article; tags }

(* Extract text from Atom text_construct *)
let atom_text_construct_to_string (tc : Syndic.Atom.text_construct) :
    string option =
  match tc with
  | Syndic.Atom.Text t -> Some t
  | Syndic.Atom.Html (_, t) -> Some t
  | Syndic.Atom.Xhtml _ -> None

(* Check if Atom text_construct is plain text (not HTML) *)
let atom_text_construct_is_plain (tc : Syndic.Atom.text_construct) : bool =
  match tc with Syndic.Atom.Text _ -> true | _ -> false

(* Convert Atom entry to our article format with tags.
   Atom has:
   - content: full entry content (Text, Html, Xhtml, Mime, or Src)
   - summary: short abstract/excerpt
   
   Strategy:
   - content_html = content if present, else summary
   - summary = entry.summary (as text) if present, else generate from content_html *)
let atom_entry_to_article ~feed_id (entry : Syndic.Atom.entry) :
    article_with_tags option =
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
        | Syndic.Atom.Xhtml _ -> None
      in
      (* Extract content from entry.content *)
      let entry_content =
        match entry.content with
        | Some (Syndic.Atom.Text t) -> Some t
        | Some (Syndic.Atom.Html (_, t)) -> Some t
        | Some (Syndic.Atom.Xhtml _) -> None
        | Some (Syndic.Atom.Mime _) -> None
        | Some (Syndic.Atom.Src _) -> None
        | None -> None
      in
      (* Extract summary from entry.summary *)
      let entry_summary = Option.bind entry.summary atom_text_construct_to_string in
      let entry_summary_is_plain =
        Option.map atom_text_construct_is_plain entry.summary
        |> Option.value ~default:false
      in
      (* content_html: prefer content, fallback to summary *)
      let content_html =
        match entry_content with Some c -> Some c | None -> entry_summary
      in
      (* summary: use entry.summary if available, else generate from content *)
      let summary =
        match entry_summary, entry_summary_is_plain with
        | Some s, true ->
            (* Plain text summary, just truncate *)
            Html_text.to_summary ~html:None ~text:(Some s)
        | Some s, false ->
            (* HTML summary, convert to text *)
            Html_text.to_summary ~html:(Some s) ~text:None
        | None, _ ->
            (* No summary, generate from content *)
            Html_text.to_summary ~html:content_html ~text:None
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
      let article =
        {
          Db.Article.feed_id;
          title;
          url;
          published_at =
            (match entry.published with
            | Some p -> Some (ptime_to_string p)
            | None -> Some (ptime_to_string entry.updated));
          content_html;
          summary;
          author;
          image_url;
        }
      in
      let tags = atom_entry_categories entry in
      Some { article; tags }

(* Fetch URL content using Piaf *)
let fetch_url ~sw ~env (url : string) : (string, string) result =
  try
    let uri = Uri.of_string url in
    match Piaf.Client.Oneshot.get ~sw env uri with
    | Error err ->
        Error (Format.asprintf "Fetch error: %a" Piaf.Error.pp_hum err)
    | Ok response ->
        let status = response.Piaf.Response.status in
        if Piaf.Status.is_successful status then
          match Piaf.Body.to_string response.body with
          | Ok body_str -> Ok body_str
          | Error err ->
              Error
                (Format.asprintf "Body read error: %a" Piaf.Error.pp_hum err)
        else Error (Printf.sprintf "HTTP %d" (Piaf.Status.to_code status))
  with exn ->
    Error (Printf.sprintf "Fetch error: %s" (Printexc.to_string exn))

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
  | None -> ( match channel.items with item :: _ -> item.author | [] -> None)

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
let fetch_feed_metadata ~sw ~env (url : string) : (feed_metadata, string) result
    =
  let fetch_result = fetch_url ~sw ~env url in
  match fetch_result with
  | Error msg -> Error msg
  | Ok content -> (
      match parse_feed content with
      | Error msg -> Error msg
      | Ok parsed_feed -> Ok (extract_metadata parsed_feed))

(* Extract articles with tags from parsed feed *)
let extract_articles_with_tags ~feed_id (feed : parsed_feed) :
    article_with_tags list =
  match feed with
  | Rss2 channel ->
      List.filter_map (rss2_item_to_article ~feed_id) channel.items
  | Atom feed -> List.filter_map (atom_entry_to_article ~feed_id) feed.entries

(* Associate tags with an article, creating tags if needed *)
let associate_tags_with_article ~article_id ~tag_names : unit =
  List.iter
    (fun tag_name ->
      match Db.Tag.get_or_create ~name:tag_name with
      | Error err ->
          Log.err (fun m ->
              m "Failed to get/create tag '%s': %a" tag_name Caqti_error.pp err)
      | Ok tag -> (
          match Db.Tag.add_to_article ~article_id ~tag_id:tag.id with
          | Error err ->
              Log.err (fun m ->
                  m "Failed to associate tag '%s' with article %d: %a" tag_name
                    article_id Caqti_error.pp err)
          | Ok () -> ()))
    tag_names

(* Get feed tags to inherit *)
let get_feed_tag_ids ~feed_id : int list =
  match Db.Tag.get_by_feed ~feed_id with
  | Error _ -> []
  | Ok tags -> List.map (fun (t : Model.Tag.t) -> t.id) tags

(* Process a single feed: fetch, parse, store articles with tags *)
let process_feed ~sw ~env (feed : Model.Rss_feed.t) : unit =
  Log.info (fun m -> m "Fetching feed %d: %s" feed.id feed.url);
  let fetch_result = fetch_url ~sw ~env feed.url in
  match fetch_result with
  | Error msg ->
      Log.err (fun m ->
          m "Failed to fetch feed %d (%s): %s" feed.id feed.url msg)
  | Ok content -> (
      match parse_feed content with
      | Error msg ->
          Log.err (fun m ->
              m "Failed to parse feed %d (%s): %s" feed.id feed.url msg)
      | Ok parsed_feed ->
          let articles_with_tags =
            extract_articles_with_tags ~feed_id:feed.id parsed_feed
          in
          let feed_tag_ids = get_feed_tag_ids ~feed_id:feed.id in
          let count = ref 0 in
          List.iter
            (fun { article; tags } ->
              (* Upsert the article *)
              match Db.Article.upsert article with
              | Error err ->
                  Log.err (fun m ->
                      m "Failed to upsert article '%s': %a"
                        (Option.value ~default:article.url article.title)
                        Caqti_error.pp err)
              | Ok () -> (
                  incr count;
                  (* Get the article ID by looking it up *)
                  match
                    Db.Article.get_by_feed_url ~feed_id:feed.id ~url:article.url
                  with
                  | Error err ->
                      Log.err (fun m ->
                          m "Failed to get article after upsert: %a"
                            Caqti_error.pp err)
                  | Ok None ->
                      Log.err (fun m ->
                          m "Article not found after upsert: %s" article.url)
                  | Ok (Some stored_article) ->
                      (* Associate article-level tags *)
                      associate_tags_with_article ~article_id:stored_article.id
                        ~tag_names:tags;
                      (* Inherit feed tags *)
                      List.iter
                        (fun tag_id ->
                          let _ =
                            Db.Tag.add_to_article ~article_id:stored_article.id
                              ~tag_id
                          in
                          ())
                        feed_tag_ids))
            articles_with_tags;
          Log.info (fun m ->
              m "Processed %d articles for feed %d" !count feed.id);
          (* Update last_fetched_at on the feed *)
          let _ = Db.Rss_feed.update_last_fetched ~id:feed.id in
          ())

(* Fetch all feeds - called by scheduler *)
let fetch_all_feeds ~sw ~env () : unit =
  Log.info (fun m -> m "Starting scheduled feed fetch");
  let result = Db.Rss_feed.list_all () in
  match result with
  | Error err ->
      Log.err (fun m -> m "Failed to list feeds: %a" Caqti_error.pp err)
  | Ok feeds ->
      (* Process feeds sequentially to avoid overwhelming the system *)
      List.iter (process_feed ~sw ~env) feeds;
      Log.info (fun m ->
          m "Completed scheduled feed fetch (%d feeds)" (List.length feeds))
