(** Contact metadata extraction from personal/site homepages. *)

module Log = (val Logs.src_log (Logs.Src.create "contact_metadata") : Logs.LOG)

module Feed = struct
  type format = Rss | Atom | Json_feed

  let pp_format fmt = function
    | Rss -> Format.fprintf fmt "RSS"
    | Atom -> Format.fprintf fmt "Atom"
    | Json_feed -> Format.fprintf fmt "JSON Feed"

  let equal_format a b =
    match (a, b) with
    | Rss, Rss | Atom, Atom | Json_feed, Json_feed -> true
    | _ -> false

  type t = { url : string; title : string option; format : format }

  let pp fmt t =
    Format.fprintf fmt "@[<hov 2>{ url = %S;@ title = %a;@ format = %a }@]"
      t.url
      (Format.pp_print_option Format.pp_print_string)
      t.title pp_format t.format

  let equal a b =
    String.equal a.url b.url
    && Option.equal String.equal a.title b.title
    && equal_format a.format b.format
end

module Classified_profile = struct
  type t = { url : string; field_type : Model.Metadata_field_type.t }

  let pp fmt t =
    Format.fprintf fmt "{ url = %S; field_type = %s }" t.url
      (Model.Metadata_field_type.name t.field_type)

  let equal a b =
    String.equal a.url b.url
    && Model.Metadata_field_type.id a.field_type
       = Model.Metadata_field_type.id b.field_type
end

type t = {
  name : string option;
  url : string option;
  email : string option;
  photo : string option;
  bio : string option;
  location : string option;
  feeds : Feed.t list;
  social_profiles : Classified_profile.t list;
}

let pp fmt t =
  Format.fprintf fmt
    "@[<hov 2>{ name = %a;@ url = %a;@ email = %a;@ photo = %a;@ bio = %a;@ \
     location = %a;@ feeds = [%d items];@ social_profiles = [%d items] }@]"
    (Format.pp_print_option Format.pp_print_string)
    t.name
    (Format.pp_print_option Format.pp_print_string)
    t.url
    (Format.pp_print_option Format.pp_print_string)
    t.email
    (Format.pp_print_option Format.pp_print_string)
    t.photo
    (Format.pp_print_option Format.pp_print_string)
    t.bio
    (Format.pp_print_option Format.pp_print_string)
    t.location (List.length t.feeds)
    (List.length t.social_profiles)

let equal a b =
  Option.equal String.equal a.name b.name
  && Option.equal String.equal a.url b.url
  && Option.equal String.equal a.email b.email
  && Option.equal String.equal a.photo b.photo
  && Option.equal String.equal a.bio b.bio
  && Option.equal String.equal a.location b.location
  && List.equal Feed.equal a.feeds b.feeds
  && List.equal Classified_profile.equal a.social_profiles b.social_profiles

let to_json t =
  let opt_field name = function
    | Some v -> [ (name, `String v) ]
    | None -> []
  in
  let feed_to_json (f : Feed.t) =
    `Assoc
      ([
         ("url", `String f.url);
         ( "format",
           `String
             (match f.format with
             | Feed.Rss -> "rss"
             | Atom -> "atom"
             | Json_feed -> "json_feed") );
       ]
      @ opt_field "title" f.title)
  in
  let profile_to_json (p : Classified_profile.t) =
    `Assoc
      [
        ("url", `String p.url);
        ("type", `String (Model.Metadata_field_type.name p.field_type));
      ]
  in
  `Assoc
    (opt_field "name" t.name @ opt_field "url" t.url @ opt_field "email" t.email
   @ opt_field "photo" t.photo @ opt_field "bio" t.bio
    @ opt_field "location" t.location
    @ [ ("feeds", `List (List.map feed_to_json t.feeds)) ]
    @ [
        ("social_profiles", `List (List.map profile_to_json t.social_profiles));
      ])

(* Classify social profile URLs into typed metadata fields *)
let classify_profiles ~email ~social_profiles : Classified_profile.t list =
  let seen = Hashtbl.create 16 in
  let dominated_by_email url =
    match email with
    | Some e -> String.equal url e || String.equal url ("mailto:" ^ e)
    | None -> false
  in
  let classify_url url : Model.Metadata_field_type.t =
    if String.starts_with ~prefix:"mailto:" (String.lowercase_ascii url) then
      Email
    else
      let get_host u =
        try Option.map String.lowercase_ascii (Uri.host (Uri.of_string u))
        with _ -> None
      in
      let host_matches ~domain host =
        String.equal host domain || String.ends_with ~suffix:("." ^ domain) host
      in
      match get_host url with
      | None -> Other
      | Some host ->
          if
            host_matches ~domain:"twitter.com" host
            || host_matches ~domain:"x.com" host
          then X
          else if host_matches ~domain:"github.com" host then GitHub
          else if host_matches ~domain:"linkedin.com" host then LinkedIn
          else if
            host_matches ~domain:"bsky.app" host
            || host_matches ~domain:"bsky.social" host
          then Bluesky
          else if host_matches ~domain:"youtube.com" host then YouTube
          else if
            host_matches ~domain:"mastodon.social" host
            || host_matches ~domain:"mastodon.online" host
            || host_matches ~domain:"fosstodon.org" host
            || host_matches ~domain:"hachyderm.io" host
          then Mastodon
          else Other
  in
  let from_email =
    Option.map
      (fun e -> Classified_profile.{ url = e; field_type = Email })
      email
    |> Option.to_list
  in
  let from_profiles =
    List.filter_map
      (fun url ->
        if Hashtbl.mem seen url || dominated_by_email url then None
        else begin
          Hashtbl.add seen url ();
          Some Classified_profile.{ url; field_type = classify_url url }
        end)
      social_profiles
  in
  from_email @ from_profiles

(* Extract feed links from HTML *)
let extract_feeds ~base_url soup : Feed.t list =
  let format_of_mime_type mime =
    let mime = String.lowercase_ascii mime in
    if String.equal mime "application/rss+xml" then Some Feed.Rss
    else if String.equal mime "application/atom+xml" then Some Feed.Atom
    else if String.equal mime "application/feed+json" then Some Feed.Json_feed
    else if String.equal mime "application/json" then Some Feed.Json_feed
    else None
  in
  let extract_feed node : Feed.t option =
    let rel = Soup.attribute "rel" node in
    let type_attr = Soup.attribute "type" node in
    let href = Soup.attribute "href" node in
    match (rel, type_attr, href) with
    | Some rel, Some mime, Some href when String.equal rel "alternate" ->
        Option.bind (format_of_mime_type mime) (fun format ->
            let url = Html_helpers.resolve_url ~base_url href in
            let title = Soup.attribute "title" node in
            Some { Feed.url; title; format })
    | _ -> None
  in
  Soup.select "link[rel=alternate]" soup
  |> Soup.to_list
  |> List.filter_map extract_feed

(* Merge contact info from multiple sources with priority ordering.
   Priority: Microformats > JSON-LD > rel-me links *)
let merge_contact ~(microformats : Extract_microformats.h_card option)
    ~(json_ld : Extract_json_ld.person option) ~(rel_me : string list)
    ~(feeds : Feed.t list) : t =
  let name =
    match microformats with
    | Some mf when Option.is_some mf.name -> mf.name
    | _ -> Option.bind json_ld (fun jl -> jl.name)
  in
  let url =
    match microformats with
    | Some mf when Option.is_some mf.url -> mf.url
    | _ -> Option.bind json_ld (fun jl -> jl.url)
  in
  let email =
    match microformats with
    | Some mf when Option.is_some mf.email -> mf.email
    | _ -> Option.bind json_ld (fun jl -> jl.email)
  in
  let photo =
    match microformats with
    | Some mf when Option.is_some mf.photo -> mf.photo
    | _ -> Option.bind json_ld (fun jl -> jl.image)
  in
  let bio = match microformats with Some mf -> mf.note | None -> None in
  let location =
    match microformats with
    | Some mf -> (
        match (mf.locality, mf.country) with
        | Some loc, Some country -> Some (loc ^ ", " ^ country)
        | Some loc, None -> Some loc
        | None, Some country -> Some country
        | None, None -> None)
    | None -> None
  in
  (* Collect social profiles from all sources *)
  let raw_profiles =
    let from_json_ld =
      Option.map (fun (jl : Extract_json_ld.person) -> jl.same_as) json_ld
      |> Option.value ~default:[]
    in
    rel_me @ from_json_ld
  in
  (* Classify and deduplicate profiles *)
  let social_profiles =
    classify_profiles ~email ~social_profiles:raw_profiles
  in
  { name; url; email; photo; bio; location; feeds; social_profiles }

let extract ~url ~html =
  let base_url = Uri.of_string url in
  let soup = Soup.parse html in
  let feeds = extract_feeds ~base_url soup in
  let json_ld = Extract_json_ld.extract soup in
  let microformats = Extract_microformats.extract ~base_url soup in
  let h_card = List.nth_opt microformats.cards 0 in
  let json_ld_person =
    match List.nth_opt json_ld.persons 0 with
    | Some p -> Some p
    | None -> Option.bind (List.nth_opt json_ld.articles 0) (fun a -> a.author)
  in
  merge_contact ~microformats:h_card ~json_ld:json_ld_person
    ~rel_me:microformats.rel_me ~feeds

let fetch ~sw ~env url =
  Log.info (fun m -> m "Fetching contact metadata for %s" url);
  match Http_client.fetch ~sw ~env url with
  | Error e ->
      Log.err (fun m -> m "Failed to fetch %s: %s" url e);
      Error e
  | Ok html ->
      let result = extract ~url ~html in
      Log.info (fun m ->
          m "Extracted contact: name=%a, %d feeds, %d profiles"
            (Format.pp_print_option Format.pp_print_string)
            result.name (List.length result.feeds)
            (List.length result.social_profiles));
      Ok result
