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

module Author = struct
  type t = {
    name : string option;
    url : string option;
    email : string option;
    photo : string option;
    bio : string option;
    location : string option;
    social_profiles : string list;
  }

  let empty =
    {
      name = None;
      url = None;
      email = None;
      photo = None;
      bio = None;
      location = None;
      social_profiles = [];
    }

  let is_empty t =
    Option.is_none t.name && Option.is_none t.url && Option.is_none t.email
    && Option.is_none t.photo && Option.is_none t.bio
    && Option.is_none t.location
    && List.length t.social_profiles = 0

  let merge a b =
    {
      name = (match a.name with Some _ -> a.name | None -> b.name);
      url = (match a.url with Some _ -> a.url | None -> b.url);
      email = (match a.email with Some _ -> a.email | None -> b.email);
      photo = (match a.photo with Some _ -> a.photo | None -> b.photo);
      bio = (match a.bio with Some _ -> a.bio | None -> b.bio);
      location =
        (match a.location with Some _ -> a.location | None -> b.location);
      social_profiles =
        (match a.social_profiles with [] -> b.social_profiles | l -> l);
    }

  let pp fmt t =
    Format.fprintf fmt
      "@[<hov 2>{ name = %a;@ url = %a;@ email = %a;@ photo = %a;@ bio = %a;@ \
       location = %a;@ social_profiles = [%a] }@]"
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
      t.location
      (Format.pp_print_list ~pp_sep:Format.pp_print_space Format.pp_print_string)
      t.social_profiles

  let equal a b =
    Option.equal String.equal a.name b.name
    && Option.equal String.equal a.url b.url
    && Option.equal String.equal a.email b.email
    && Option.equal String.equal a.photo b.photo
    && Option.equal String.equal a.bio b.bio
    && Option.equal String.equal a.location b.location
    && List.equal String.equal a.social_profiles b.social_profiles
end

module Content = struct
  type t = {
    title : string option;
    description : string option;
    published_at : string option;
    modified_at : string option;
    author : Author.t option;
    image : string option;
    tags : string list;
    content_type : string option;
  }

  let empty =
    {
      title = None;
      description = None;
      published_at = None;
      modified_at = None;
      author = None;
      image = None;
      tags = [];
      content_type = None;
    }

  let pp fmt t =
    Format.fprintf fmt
      "@[<hov 2>{ title = %a;@ description = %a;@ published_at = %a;@ \
       modified_at = %a;@ author = %a;@ image = %a;@ tags = [%a];@ \
       content_type = %a }@]"
      (Format.pp_print_option Format.pp_print_string)
      t.title
      (Format.pp_print_option Format.pp_print_string)
      t.description
      (Format.pp_print_option Format.pp_print_string)
      t.published_at
      (Format.pp_print_option Format.pp_print_string)
      t.modified_at
      (Format.pp_print_option Author.pp)
      t.author
      (Format.pp_print_option Format.pp_print_string)
      t.image
      (Format.pp_print_list ~pp_sep:Format.pp_print_space Format.pp_print_string)
      t.tags
      (Format.pp_print_option Format.pp_print_string)
      t.content_type

  let equal a b =
    Option.equal String.equal a.title b.title
    && Option.equal String.equal a.description b.description
    && Option.equal String.equal a.published_at b.published_at
    && Option.equal String.equal a.modified_at b.modified_at
    && Option.equal Author.equal a.author b.author
    && Option.equal String.equal a.image b.image
    && List.equal String.equal a.tags b.tags
    && Option.equal String.equal a.content_type b.content_type
end

module Site = struct
  type t = {
    name : string option;
    canonical_url : string option;
    favicon : string option;
    locale : string option;
    webmention_endpoint : string option;
  }

  let empty =
    {
      name = None;
      canonical_url = None;
      favicon = None;
      locale = None;
      webmention_endpoint = None;
    }

  let pp fmt t =
    Format.fprintf fmt
      "@[<hov 2>{ name = %a;@ canonical_url = %a;@ favicon = %a;@ locale = \
       %a;@ webmention_endpoint = %a }@]"
      (Format.pp_print_option Format.pp_print_string)
      t.name
      (Format.pp_print_option Format.pp_print_string)
      t.canonical_url
      (Format.pp_print_option Format.pp_print_string)
      t.favicon
      (Format.pp_print_option Format.pp_print_string)
      t.locale
      (Format.pp_print_option Format.pp_print_string)
      t.webmention_endpoint

  let equal a b =
    Option.equal String.equal a.name b.name
    && Option.equal String.equal a.canonical_url b.canonical_url
    && Option.equal String.equal a.favicon b.favicon
    && Option.equal String.equal a.locale b.locale
    && Option.equal String.equal a.webmention_endpoint b.webmention_endpoint
end

type t = {
  url : string;
  feeds : Feed.t list;
  author : Author.t option;
  content : Content.t;
  site : Site.t;
  raw_json_ld : Yojson.Safe.t list;
}

let pp fmt t =
  Format.fprintf fmt
    "@[<v 2>{ url = %S;@ feeds = [%a];@ author = %a;@ content = %a;@ site = \
     %a;@ raw_json_ld = <%d items> }@]"
    t.url
    (Format.pp_print_list ~pp_sep:Format.pp_print_space Feed.pp)
    t.feeds
    (Format.pp_print_option Author.pp)
    t.author Content.pp t.content Site.pp t.site
    (List.length t.raw_json_ld)

let equal a b =
  String.equal a.url b.url
  && List.equal Feed.equal a.feeds b.feeds
  && Option.equal Author.equal a.author b.author
  && Content.equal a.content b.content
  && Site.equal a.site b.site
