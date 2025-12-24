(* JSON serialization for URL metadata types and API response *)

let string_opt_to_json = function Some s -> `String s | None -> `Null
let string_list_to_json l = `List (List.map (fun s -> `String s) l)

module Feed = struct
  let format_to_json = function
    | Types.Feed.Rss -> `String "rss"
    | Types.Feed.Atom -> `String "atom"
    | Types.Feed.Json_feed -> `String "json_feed"

  let to_json (t : Types.Feed.t) : Yojson.Safe.t =
    `Assoc
      [
        ("url", `String t.url);
        ("title", string_opt_to_json t.title);
        ("format", format_to_json t.format);
      ]

  let list_to_json feeds = `List (List.map to_json feeds)
end

module Author = struct
  let to_json (t : Types.Author.t) : Yojson.Safe.t =
    `Assoc
      [
        ("name", string_opt_to_json t.name);
        ("url", string_opt_to_json t.url);
        ("email", string_opt_to_json t.email);
        ("photo", string_opt_to_json t.photo);
        ("bio", string_opt_to_json t.bio);
        ("location", string_opt_to_json t.location);
        ("social_profiles", string_list_to_json t.social_profiles);
      ]

  let opt_to_json = function Some a -> to_json a | None -> `Null
end

module Content = struct
  let to_json (t : Types.Content.t) : Yojson.Safe.t =
    `Assoc
      [
        ("title", string_opt_to_json t.title);
        ("description", string_opt_to_json t.description);
        ("published_at", string_opt_to_json t.published_at);
        ("modified_at", string_opt_to_json t.modified_at);
        ("author", Author.opt_to_json t.author);
        ("image", string_opt_to_json t.image);
        ("tags", string_list_to_json t.tags);
        ("content_type", string_opt_to_json t.content_type);
      ]
end

module Site = struct
  let to_json (t : Types.Site.t) : Yojson.Safe.t =
    `Assoc
      [
        ("name", string_opt_to_json t.name);
        ("canonical_url", string_opt_to_json t.canonical_url);
        ("favicon", string_opt_to_json t.favicon);
        ("locale", string_opt_to_json t.locale);
        ("webmention_endpoint", string_opt_to_json t.webmention_endpoint);
      ]
end

(* Individual extractor results for raw/debug output *)
module Raw = struct
  module Html_meta = struct
    let to_json (t : Extract_html_meta.t) : Yojson.Safe.t =
      `Assoc
        [
          ("title", string_opt_to_json t.title);
          ("description", string_opt_to_json t.description);
          ("author", string_opt_to_json t.author);
          ("canonical", string_opt_to_json t.canonical);
          ("favicon", string_opt_to_json t.favicon);
          ("webmention", string_opt_to_json t.webmention);
        ]
  end

  module Opengraph = struct
    let to_json (t : Extract_opengraph.t) : Yojson.Safe.t =
      `Assoc
        [
          ("title", string_opt_to_json t.title);
          ("og_type", string_opt_to_json t.og_type);
          ("url", string_opt_to_json t.url);
          ("image", string_opt_to_json t.image);
          ("description", string_opt_to_json t.description);
          ("site_name", string_opt_to_json t.site_name);
          ("locale", string_opt_to_json t.locale);
          ("author", string_opt_to_json t.author);
          ("published_time", string_opt_to_json t.published_time);
          ("modified_time", string_opt_to_json t.modified_time);
          ("tags", string_list_to_json t.tags);
        ]
  end

  module Twitter = struct
    let to_json (t : Extract_twitter.t) : Yojson.Safe.t =
      `Assoc
        [
          ("card_type", string_opt_to_json t.card_type);
          ("site", string_opt_to_json t.site);
          ("creator", string_opt_to_json t.creator);
          ("title", string_opt_to_json t.title);
          ("description", string_opt_to_json t.description);
          ("image", string_opt_to_json t.image);
        ]
  end

  module Json_ld = struct
    let person_to_json (p : Extract_json_ld.person) : Yojson.Safe.t =
      `Assoc
        [
          ("name", string_opt_to_json p.name);
          ("url", string_opt_to_json p.url);
          ("image", string_opt_to_json p.image);
          ("email", string_opt_to_json p.email);
          ("job_title", string_opt_to_json p.job_title);
          ("same_as", string_list_to_json p.same_as);
        ]

    let article_to_json (a : Extract_json_ld.article) : Yojson.Safe.t =
      `Assoc
        [
          ("headline", string_opt_to_json a.headline);
          ( "author",
            match a.author with Some p -> person_to_json p | None -> `Null );
          ("date_published", string_opt_to_json a.date_published);
          ("date_modified", string_opt_to_json a.date_modified);
          ("description", string_opt_to_json a.description);
          ("image", string_opt_to_json a.image);
        ]

    let to_json (t : Extract_json_ld.extracted) : Yojson.Safe.t =
      `Assoc
        [
          ("persons", `List (List.map person_to_json t.persons));
          ("articles", `List (List.map article_to_json t.articles));
          ("raw", `List t.raw);
        ]
  end

  module Microformats = struct
    let h_card_to_json (c : Extract_microformats.h_card) : Yojson.Safe.t =
      `Assoc
        [
          ("name", string_opt_to_json c.name);
          ("url", string_opt_to_json c.url);
          ("photo", string_opt_to_json c.photo);
          ("email", string_opt_to_json c.email);
          ("note", string_opt_to_json c.note);
          ("locality", string_opt_to_json c.locality);
          ("country", string_opt_to_json c.country);
        ]

    let h_entry_to_json (e : Extract_microformats.h_entry) : Yojson.Safe.t =
      `Assoc
        [
          ("name", string_opt_to_json e.name);
          ("summary", string_opt_to_json e.summary);
          ("published", string_opt_to_json e.published);
          ("updated", string_opt_to_json e.updated);
          ( "author",
            match e.author with Some c -> h_card_to_json c | None -> `Null );
          ("categories", string_list_to_json e.categories);
        ]

    let to_json (t : Extract_microformats.t) : Yojson.Safe.t =
      `Assoc
        [
          ("cards", `List (List.map h_card_to_json t.cards));
          ("entries", `List (List.map h_entry_to_json t.entries));
          ("rel_me", string_list_to_json t.rel_me);
        ]
  end
end

(* Main merged result *)
let to_json (t : Types.t) : Yojson.Safe.t =
  `Assoc
    [
      ("url", `String t.url);
      ("feeds", Feed.list_to_json t.feeds);
      ("author", Author.opt_to_json t.author);
      ("content", Content.to_json t.content);
      ("site", Site.to_json t.site);
      ("raw_json_ld", `List t.raw_json_ld);
    ]

(* Full response with both merged and individual extractor data *)
type full_response = {
  merged : Types.t;
  raw_html_meta : Extract_html_meta.t;
  raw_opengraph : Extract_opengraph.t;
  raw_twitter : Extract_twitter.t;
  raw_json_ld : Extract_json_ld.extracted;
  raw_microformats : Extract_microformats.t;
}

let full_response_to_json (r : full_response) : Yojson.Safe.t =
  `Assoc
    [
      ("merged", to_json r.merged);
      ( "sources",
        `Assoc
          [
            ("html_meta", Raw.Html_meta.to_json r.raw_html_meta);
            ("opengraph", Raw.Opengraph.to_json r.raw_opengraph);
            ("twitter", Raw.Twitter.to_json r.raw_twitter);
            ("json_ld", Raw.Json_ld.to_json r.raw_json_ld);
            ("microformats", Raw.Microformats.to_json r.raw_microformats);
          ] );
    ]
