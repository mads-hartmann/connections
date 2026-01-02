module Log = (val Logs.src_log (Logs.Src.create "article_metadata") : Logs.LOG)

type t = {
  title : string option;
  description : string option;
  image : string option;
  published_at : string option;
  modified_at : string option;
  author_name : string option;
  site_name : string option;
  canonical_url : string option;
  tags : string list;
  content_type : string option;
}

let pp fmt t =
  Format.fprintf fmt
    "@[<hov 2>{ title = %a;@ description = %a;@ image = %a;@ published_at = \
     %a;@ modified_at = %a;@ author_name = %a;@ site_name = %a;@ canonical_url \
     = %a;@ tags = [%d items];@ content_type = %a }@]"
    (Format.pp_print_option Format.pp_print_string)
    t.title
    (Format.pp_print_option Format.pp_print_string)
    t.description
    (Format.pp_print_option Format.pp_print_string)
    t.image
    (Format.pp_print_option Format.pp_print_string)
    t.published_at
    (Format.pp_print_option Format.pp_print_string)
    t.modified_at
    (Format.pp_print_option Format.pp_print_string)
    t.author_name
    (Format.pp_print_option Format.pp_print_string)
    t.site_name
    (Format.pp_print_option Format.pp_print_string)
    t.canonical_url (List.length t.tags)
    (Format.pp_print_option Format.pp_print_string)
    t.content_type

let equal a b =
  Option.equal String.equal a.title b.title
  && Option.equal String.equal a.description b.description
  && Option.equal String.equal a.image b.image
  && Option.equal String.equal a.published_at b.published_at
  && Option.equal String.equal a.modified_at b.modified_at
  && Option.equal String.equal a.author_name b.author_name
  && Option.equal String.equal a.site_name b.site_name
  && Option.equal String.equal a.canonical_url b.canonical_url
  && List.equal String.equal a.tags b.tags
  && Option.equal String.equal a.content_type b.content_type

let to_json t =
  let opt_field name = function
    | Some v -> [ (name, `String v) ]
    | None -> []
  in
  `Assoc
    (opt_field "title" t.title
    @ opt_field "description" t.description
    @ opt_field "image" t.image
    @ opt_field "published_at" t.published_at
    @ opt_field "modified_at" t.modified_at
    @ opt_field "author_name" t.author_name
    @ opt_field "site_name" t.site_name
    @ opt_field "canonical_url" t.canonical_url
    @ [ ("tags", `List (List.map (fun s -> `String s) t.tags)) ]
    @ opt_field "content_type" t.content_type)

let first_some options = List.find_opt Option.is_some options |> Option.join

(* Merge article info from multiple sources with priority ordering.
   Priority: JSON-LD > OpenGraph > Twitter > HTML meta *)
let merge_article ~(json_ld : Extract_json_ld.article option)
    ~(opengraph : Extract_opengraph.t) ~(twitter : Extract_twitter.t)
    ~(html_meta : Extract_html_meta.t) : t =
  let title =
    first_some
      [
        Option.bind json_ld (fun a -> a.headline);
        opengraph.title;
        twitter.title;
        html_meta.title;
      ]
  in
  let description =
    first_some
      [
        Option.bind json_ld (fun a -> a.description);
        opengraph.description;
        twitter.description;
        html_meta.description;
      ]
  in
  let image =
    first_some
      [ Option.bind json_ld (fun a -> a.image); opengraph.image; twitter.image ]
  in
  let published_at =
    first_some
      [
        Option.bind json_ld (fun a -> a.date_published);
        opengraph.published_time;
      ]
  in
  let modified_at =
    first_some
      [
        Option.bind json_ld (fun a -> a.date_modified); opengraph.modified_time;
      ]
  in
  let author_name =
    first_some
      [
        Option.bind json_ld (fun a -> Option.bind a.author (fun p -> p.name));
        opengraph.author;
        twitter.creator;
        html_meta.author;
      ]
  in
  let site_name = opengraph.site_name in
  let canonical_url = first_some [ opengraph.url; html_meta.canonical ] in
  let tags = opengraph.tags in
  let content_type = opengraph.og_type in
  {
    title;
    description;
    image;
    published_at;
    modified_at;
    author_name;
    site_name;
    canonical_url;
    tags;
    content_type;
  }

let extract ~url ~html =
  let _ = url in
  let soup = Soup.parse html in
  let json_ld = Extract_json_ld.extract soup in
  let opengraph = Extract_opengraph.extract soup in
  let twitter = Extract_twitter.extract soup in
  let html_meta =
    Extract_html_meta.extract ~base_url:(Uri.of_string url) soup
  in
  let json_ld_article = List.nth_opt json_ld.articles 0 in
  merge_article ~json_ld:json_ld_article ~opengraph ~twitter ~html_meta

let fetch ~sw ~env url =
  Log.info (fun m -> m "Fetching article metadata for %s" url);
  match Fetch.fetch_html ~sw ~env url with
  | Error e ->
      Log.err (fun m -> m "Failed to fetch %s: %s" url e);
      Error e
  | Ok html ->
      let result = extract ~url ~html in
      Log.info (fun m ->
          m "Extracted article: title=%a, site=%a"
            (Format.pp_print_option Format.pp_print_string)
            result.title
            (Format.pp_print_option Format.pp_print_string)
            result.site_name);
      Ok result
