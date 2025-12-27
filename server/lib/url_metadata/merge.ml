(* Merge metadata from multiple sources with priority ordering *)

(* Priority: Microformats > JSON-LD > OpenGraph > Twitter > HTML meta *)

let first_some options = List.find_opt Option.is_some options |> Option.join

(* Classify social profiles into typed metadata fields *)
let classify_profiles ~email ~social_profiles : Types.Classified_profile.t list =
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
          if host_matches ~domain:"twitter.com" host
             || host_matches ~domain:"x.com" host
          then X
          else if host_matches ~domain:"github.com" host then GitHub
          else if host_matches ~domain:"linkedin.com" host then LinkedIn
          else if host_matches ~domain:"bsky.app" host
                  || host_matches ~domain:"bsky.social" host
          then Bluesky
          else Other
  in
  let from_email =
    Option.map
      (fun e -> Types.Classified_profile.{ url = e; field_type = Email })
      email
    |> Option.to_list
  in
  let from_profiles =
    List.filter_map
      (fun url ->
        if Hashtbl.mem seen url || dominated_by_email url then None
        else begin
          Hashtbl.add seen url ();
          Some Types.Classified_profile.{ url; field_type = classify_url url }
        end)
      social_profiles
  in
  from_email @ from_profiles

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
          classified_profiles = [];
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
          classified_profiles = [];
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
  (* Create author from rel-me links if no other source provides one *)
  let from_rel_me =
    match rel_me with
    | [] -> None
    | _ -> Some { Types.Author.empty with social_profiles = rel_me }
  in
  (* Merge in priority order *)
  let candidates =
    [ from_microformats; from_json_ld; from_og; from_twitter; from_html; from_rel_me ]
  in
  match List.filter_map Fun.id candidates with
  | [] -> None
  | first :: rest ->
      let merged = List.fold_left Types.Author.merge first rest in
      (* Classify social profiles after merging *)
      let classified =
        classify_profiles ~email:merged.email
          ~social_profiles:merged.social_profiles
      in
      let result = { merged with classified_profiles = classified } in
      (* Only return author if it has meaningful content *)
      if Types.Author.is_empty result && List.length classified = 0 then None
      else Some result

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
