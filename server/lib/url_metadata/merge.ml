(* Merge metadata from multiple sources with priority ordering *)

(* Priority: Microformats > JSON-LD > OpenGraph > Twitter > HTML meta *)

let first_some options = List.find_opt Option.is_some options |> Option.join

let merge_author ~(microformats : Extract_microformats.h_card option)
    ~(json_ld : Extract_json_ld.person option) ~(opengraph : string option)
    ~(twitter : string option) ~(html_meta : string option)
    ~(rel_me : string list) : Types.Author.t option =
  let from_microformats =
    Option.map
      (fun (mf : Extract_microformats.h_card) : Types.Author.t ->
        {
          name = mf.name;
          url = mf.url;
          email = mf.email;
          photo = mf.photo;
          bio = mf.note;
          location =
            (match (mf.locality, mf.country) with
            | Some loc, Some country -> Some (loc ^ ", " ^ country)
            | Some loc, None -> Some loc
            | None, Some country -> Some country
            | None, None -> None);
          social_profiles = rel_me;
        })
      microformats
  in
  let from_json_ld =
    Option.map
      (fun (jl : Extract_json_ld.person) : Types.Author.t ->
        {
          name = jl.name;
          url = jl.url;
          email = jl.email;
          photo = jl.image;
          bio = None;
          location = None;
          social_profiles = jl.same_as;
        })
      json_ld
  in
  let from_og =
    Option.map
      (fun name : Types.Author.t ->
        { Types.Author.empty with name = Some name })
      opengraph
  in
  let from_twitter =
    Option.map
      (fun creator : Types.Author.t ->
        { Types.Author.empty with name = Some creator })
      twitter
  in
  let from_html =
    Option.map
      (fun author : Types.Author.t ->
        { Types.Author.empty with name = Some author })
      html_meta
  in
  (* Merge in priority order *)
  let candidates =
    [ from_microformats; from_json_ld; from_og; from_twitter; from_html ]
  in
  match List.filter_map Fun.id candidates with
  | [] -> None
  | first :: rest ->
      let merged = List.fold_left Types.Author.merge first rest in
      if Types.Author.is_empty merged then None else Some merged

let merge_content ~(microformats : Extract_microformats.h_entry option)
    ~(json_ld : Extract_json_ld.article option)
    ~(opengraph : Extract_opengraph.t) ~(twitter : Extract_twitter.t)
    ~(html_meta : Extract_html_meta.t) ~(author : Types.Author.t option) :
    Types.Content.t =
  let title =
    first_some
      [
        Option.bind microformats (fun e -> e.name);
        Option.bind json_ld (fun a -> a.headline);
        opengraph.title;
        twitter.title;
        html_meta.title;
      ]
  in
  let description =
    first_some
      [
        Option.bind microformats (fun e -> e.summary);
        Option.bind json_ld (fun a -> a.description);
        opengraph.description;
        twitter.description;
        html_meta.description;
      ]
  in
  let published_at =
    first_some
      [
        Option.bind microformats (fun e -> e.published);
        Option.bind json_ld (fun a -> a.date_published);
        opengraph.published_time;
      ]
  in
  let modified_at =
    first_some
      [
        Option.bind microformats (fun e -> e.updated);
        Option.bind json_ld (fun a -> a.date_modified);
        opengraph.modified_time;
      ]
  in
  let image =
    first_some
      [ Option.bind json_ld (fun a -> a.image); opengraph.image; twitter.image ]
  in
  let tags =
    match microformats with
    | Some e when List.length e.categories > 0 -> e.categories
    | _ -> opengraph.tags
  in
  let content_type = opengraph.og_type in
  {
    title;
    description;
    published_at;
    modified_at;
    author;
    image;
    tags;
    content_type;
  }

let merge_site ~(opengraph : Extract_opengraph.t)
    ~(html_meta : Extract_html_meta.t) : Types.Site.t =
  {
    name = opengraph.site_name;
    canonical_url = first_some [ opengraph.url; html_meta.canonical ];
    favicon = html_meta.favicon;
    locale = opengraph.locale;
    webmention_endpoint = html_meta.webmention;
  }
