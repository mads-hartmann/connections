(* URL Metadata Extraction Module

   Fetches a URL and extracts structured metadata from multiple semantic web
   standards: Microformats2, JSON-LD/Schema.org, Open Graph, Twitter Cards,
   and standard HTML meta tags. *)

module Log = (val Logs.src_log (Logs.Src.create "url_metadata") : Logs.LOG)

(* Re-export types and extractors *)
module Feed = Types.Feed
module Author = Types.Author
module Content = Types.Content
module Site = Types.Site
module Extract_opengraph = Extract_opengraph
module Fetch = Fetch
module Contact_metadata = Contact_metadata

type t = Types.t = {
  url : string;
  feeds : Feed.t list;
  author : Author.t option;
  content : Content.t;
  site : Site.t;
  raw_json_ld : Yojson.Safe.t list;
}

let pp = Types.pp
let equal = Types.equal

(* Internal extraction that returns both merged and raw data *)
let extract_full_internal ~url ~html =
  let base_url = Uri.of_string url in
  let soup = Soup.parse html in

  (* Run all extractors *)
  let feeds = Extract_feeds.extract ~base_url soup in
  let html_meta = Extract_html_meta.extract ~base_url soup in
  let opengraph = Extract_opengraph.extract soup in
  let twitter = Extract_twitter.extract soup in
  let json_ld = Extract_json_ld.extract soup in
  let microformats = Extract_microformats.extract ~base_url soup in

  (* Merge with priority *)
  (* Get JSON-LD person: prefer standalone Person, fallback to article author *)
  let json_ld_person =
    match List.nth_opt json_ld.persons 0 with
    | Some p -> Some p
    | None -> Option.bind (List.nth_opt json_ld.articles 0) (fun a -> a.author)
  in
  let author =
    Merge.merge_author
      ~microformats:(List.nth_opt microformats.cards 0)
      ~json_ld:json_ld_person ~opengraph:opengraph.author
      ~twitter:twitter.creator ~html_meta:html_meta.author
      ~rel_me:microformats.rel_me
  in

  let content =
    Merge.merge_content
      ~microformats:(List.nth_opt microformats.entries 0)
      ~json_ld:(List.nth_opt json_ld.articles 0)
      ~opengraph ~twitter ~html_meta ~author
  in

  let site = Merge.merge_site ~opengraph ~html_meta in

  let merged =
    { url; feeds; author; content; site; raw_json_ld = json_ld.raw }
  in
  ( merged,
    {
      Json.merged;
      raw_html_meta = html_meta;
      raw_opengraph = opengraph;
      raw_twitter = twitter;
      raw_json_ld = json_ld;
      raw_microformats = microformats;
    } )

(* Extract metadata from already-fetched HTML *)
let extract ~url ~html : t = fst (extract_full_internal ~url ~html)

(* Extract with full response including individual extractor data *)
let extract_full ~url ~html : Json.full_response =
  snd (extract_full_internal ~url ~html)

(* Fetch URL and extract all metadata *)
let fetch ~sw ~env (url : string) : (t, string) result =
  Log.info (fun m -> m "Fetching metadata for %s" url);
  match Fetch.fetch_html ~sw ~env url with
  | Error e ->
      Log.err (fun m -> m "Failed to fetch %s: %s" url e);
      Error e
  | Ok html ->
      let result = extract ~url ~html in
      Log.info (fun m ->
          m "Extracted metadata: %d feeds, author=%b" (List.length result.feeds)
            (Option.is_some result.author));
      Ok result

(* Fetch URL and extract with full response *)
let fetch_full ~sw ~env (url : string) : (Json.full_response, string) result =
  Log.info (fun m -> m "Fetching full metadata for %s" url);
  match Fetch.fetch_html ~sw ~env url with
  | Error e ->
      Log.err (fun m -> m "Failed to fetch %s: %s" url e);
      Error e
  | Ok html ->
      let result = extract_full ~url ~html in
      Log.info (fun m ->
          m "Extracted full metadata: %d feeds, author=%b"
            (List.length result.merged.feeds)
            (Option.is_some result.merged.author));
      Ok result

(* JSON serialization *)
let to_json = Json.to_json
let full_response_to_json = Json.full_response_to_json
