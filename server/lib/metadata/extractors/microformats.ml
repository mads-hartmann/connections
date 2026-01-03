(* Extract Microformats2 data (h-card, h-entry, rel-me) *)

type h_card = {
  name : string option;
  url : string option;
  photo : string option;
  email : string option;
  note : string option;
  locality : string option;
  country : string option;
}

type h_entry = {
  name : string option;
  summary : string option;
  published : string option;
  updated : string option;
  author : h_card option;
  categories : string list;
}

type t = { cards : h_card list; entries : h_entry list; rel_me : string list }

let empty_card =
  {
    name = None;
    url = None;
    photo = None;
    email = None;
    note = None;
    locality = None;
    country = None;
  }

let empty_entry =
  {
    name = None;
    summary = None;
    published = None;
    updated = None;
    author = None;
    categories = [];
  }

let empty = { cards = []; entries = []; rel_me = [] }

(* Check if element has a specific class *)
let has_class cls node =
  match Soup.attribute "class" node with
  | None -> false
  | Some classes ->
      String.split_on_char ' ' classes |> List.exists (String.equal cls)

(* Find first child element with class *)
let find_class cls node =
  Soup.descendants node |> Soup.elements
  |> Soup.filter (has_class cls)
  |> Soup.first

(* Find all child elements with class *)
let find_all_class cls node =
  Soup.descendants node |> Soup.elements |> Soup.filter (has_class cls)

(* Extract p-* property (plain text) *)
let extract_p_property cls node =
  Option.bind (find_class cls node) (fun el ->
      let text = Soup.trimmed_texts el |> String.concat " " in
      if String.length text > 0 then Some text else None)

(* Extract u-* property (URL) *)
let extract_u_property ~base_url cls node =
  Option.bind (find_class cls node) (fun el ->
      (* Try href first (for links), then src (for images), then text content *)
      let url =
        match Soup.attribute "href" el with
        | Some href -> Some href
        | None -> (
            match Soup.attribute "src" el with
            | Some src -> Some src
            | None ->
                let text = Soup.trimmed_texts el |> String.concat "" in
                if String.length text > 0 then Some text else None)
      in
      Option.map (Html_helpers.resolve_url ~base_url) url)

(* Extract dt-* property (datetime) *)
let extract_dt_property cls node =
  Option.bind (find_class cls node) (fun el ->
      (* Try datetime attribute first, then title, then text *)
      match Soup.attribute "datetime" el with
      | Some dt -> Some dt
      | None -> (
          match Soup.attribute "title" el with
          | Some t -> Some t
          | None ->
              let text = Soup.trimmed_texts el |> String.concat "" in
              if String.length text > 0 then Some text else None))

(* Extract all p-category values *)
let extract_categories node =
  find_all_class "p-category" node
  |> Soup.to_list
  |> List.filter_map (fun el ->
      let text = Soup.trimmed_texts el |> String.concat " " in
      if String.length text > 0 then Some text else None)

(* Parse an h-card element *)
let parse_h_card ~base_url node : h_card =
  {
    name = extract_p_property "p-name" node;
    url = extract_u_property ~base_url "u-url" node;
    photo = extract_u_property ~base_url "u-photo" node;
    email = extract_u_property ~base_url "u-email" node;
    note = extract_p_property "p-note" node;
    locality = extract_p_property "p-locality" node;
    country = extract_p_property "p-country-name" node;
  }

(* Parse an h-entry element *)
let parse_h_entry ~base_url node : h_entry =
  let author =
    Option.map (parse_h_card ~base_url) (find_class "p-author" node)
  in
  {
    name = extract_p_property "p-name" node;
    summary = extract_p_property "p-summary" node;
    published = extract_dt_property "dt-published" node;
    updated = extract_dt_property "dt-updated" node;
    author;
    categories = extract_categories node;
  }

(* Extract rel-me links *)
let extract_rel_me ~base_url soup =
  Soup.select "a[rel~=me]" soup
  |> Soup.to_list
  |> List.filter_map (fun node ->
      Option.map
        (Html_helpers.resolve_url ~base_url)
        (Soup.attribute "href" node))

(* Known social platform domains for fallback detection *)
let social_domains =
  [
    "twitter.com";
    "x.com";
    "github.com";
    "linkedin.com";
    "bsky.app";
    "bsky.social";
    "mastodon.social";
    "youtube.com";
    "instagram.com";
    "facebook.com";
    "threads.net";
  ]

(* Check if a URL is a social profile link (not a specific post/status) *)
let is_social_profile_url url =
  let uri = Uri.of_string url in
  let host = Option.map String.lowercase_ascii (Uri.host uri) in
  let path = Uri.path uri in
  let query = Uri.query uri in
  let is_social_domain h =
    List.exists
      (fun domain ->
        String.equal h domain || String.ends_with ~suffix:("." ^ domain) h)
      social_domains
  in
  match host with
  | None -> false
  | Some h when not (is_social_domain h) -> false
  | Some h ->
      let segments =
        String.split_on_char '/' path
        |> List.filter (fun s -> String.length s > 0)
      in
      (* Filter out specific posts/statuses - we want profile links only *)
      let is_status_url =
        List.exists
          (fun segment ->
            String.equal segment "status"
            || String.equal segment "statuses"
            || String.equal segment "posts"
            || String.equal segment "p"
            || String.equal segment "watch")
          segments
      in
      (* For GitHub, profile is just /username - filter out repos and query pages *)
      let is_github_non_profile =
        (String.equal h "github.com" || String.ends_with ~suffix:".github.com" h)
        && (List.length segments > 1 || List.length query > 0)
      in
      (* For YouTube, profile is /@username or /c/channel or /channel/id *)
      let is_youtube_profile =
        (String.equal h "youtube.com"
        || String.ends_with ~suffix:".youtube.com" h)
        &&
        match segments with
        | [ username ] when String.starts_with ~prefix:"@" username -> true
        | [ "c"; _ ] -> true
        | [ "channel"; _ ] -> true
        | [ "user"; _ ] -> true
        | _ -> false
      in
      let is_youtube =
        String.equal h "youtube.com"
        || String.ends_with ~suffix:".youtube.com" h
      in
      (not is_status_url)
      && (not is_github_non_profile)
      && ((not is_youtube) || is_youtube_profile)

(* Extract social links by URL pattern as fallback when rel="me" is missing *)
let extract_social_links_by_pattern ~base_url soup =
  let seen = Hashtbl.create 16 in
  Soup.select "a[href]" soup |> Soup.to_list
  |> List.filter_map (fun node ->
      Option.bind (Soup.attribute "href" node) (fun href ->
          let url = Html_helpers.resolve_url ~base_url href in
          if is_social_profile_url url && not (Hashtbl.mem seen url) then begin
            Hashtbl.add seen url ();
            Some url
          end
          else None))

(* Extract mailto links *)
let extract_mailto_links soup =
  Soup.select "a[href^='mailto:']" soup
  |> Soup.to_list
  |> List.filter_map (fun node -> Soup.attribute "href" node)

let extract ~base_url soup : t =
  let cards =
    Soup.select ".h-card" soup |> Soup.to_list
    |> List.map (parse_h_card ~base_url)
  in
  let entries =
    Soup.select ".h-entry" soup
    |> Soup.to_list
    |> List.map (parse_h_entry ~base_url)
  in
  let rel_me = extract_rel_me ~base_url soup in
  (* Use rel="me" links if available, otherwise fall back to URL pattern detection *)
  let social_links =
    match rel_me with
    | [] ->
        let by_pattern = extract_social_links_by_pattern ~base_url soup in
        let mailto = extract_mailto_links soup in
        by_pattern @ mailto
    | _ -> rel_me
  in
  { cards; entries; rel_me = social_links }

let pp_h_card fmt (c : h_card) =
  Format.fprintf fmt "{ name = %a; url = %a }"
    (Format.pp_print_option Format.pp_print_string)
    c.name
    (Format.pp_print_option Format.pp_print_string)
    c.url

let equal_h_card (a : h_card) (b : h_card) =
  Option.equal String.equal a.name b.name
  && Option.equal String.equal a.url b.url
  && Option.equal String.equal a.photo b.photo
  && Option.equal String.equal a.email b.email
  && Option.equal String.equal a.note b.note
  && Option.equal String.equal a.locality b.locality
  && Option.equal String.equal a.country b.country

let pp_h_entry fmt e =
  Format.fprintf fmt "{ name = %a; summary = %a }"
    (Format.pp_print_option Format.pp_print_string)
    e.name
    (Format.pp_print_option Format.pp_print_string)
    e.summary

let equal_h_entry a b =
  Option.equal String.equal a.name b.name
  && Option.equal String.equal a.summary b.summary
  && Option.equal String.equal a.published b.published
  && Option.equal String.equal a.updated b.updated
  && Option.equal equal_h_card a.author b.author
  && List.equal String.equal a.categories b.categories

let pp fmt t =
  Format.fprintf fmt "{ cards = [%d]; entries = [%d]; rel_me = [%d] }"
    (List.length t.cards) (List.length t.entries) (List.length t.rel_me)

let equal a b =
  List.equal equal_h_card a.cards b.cards
  && List.equal equal_h_entry a.entries b.entries
  && List.equal String.equal a.rel_me b.rel_me
