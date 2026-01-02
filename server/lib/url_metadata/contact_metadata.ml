module Log = (val Logs.src_log (Logs.Src.create "contact_metadata") : Logs.LOG)

type t = {
  name : string option;
  url : string option;
  email : string option;
  photo : string option;
  bio : string option;
  location : string option;
  feeds : Types.Feed.t list;
  social_profiles : Types.Classified_profile.t list;
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
  && List.equal Types.Feed.equal a.feeds b.feeds
  && List.equal Types.Classified_profile.equal a.social_profiles
       b.social_profiles

let to_json t =
  let opt_field name = function
    | Some v -> [ (name, `String v) ]
    | None -> []
  in
  let feed_to_json (f : Types.Feed.t) =
    `Assoc
      ([
         ("url", `String f.url);
         ( "format",
           `String
             (match f.format with
             | Types.Feed.Rss -> "rss"
             | Atom -> "atom"
             | Json_feed -> "json_feed") );
       ]
      @ opt_field "title" f.title)
  in
  let profile_to_json (p : Types.Classified_profile.t) =
    `Assoc
      [
        ("url", `String p.url);
        ("type", `String (Model.Metadata_field_type.name p.field_type));
      ]
  in
  `Assoc
    (opt_field "name" t.name
    @ opt_field "url" t.url
    @ opt_field "email" t.email
    @ opt_field "photo" t.photo
    @ opt_field "bio" t.bio
    @ opt_field "location" t.location
    @ [ ("feeds", `List (List.map feed_to_json t.feeds)) ]
    @ [ ("social_profiles", `List (List.map profile_to_json t.social_profiles)) ]
    )

(* Merge contact info from multiple sources with priority ordering.
   Priority: Microformats > JSON-LD > rel-me links *)
let merge_contact ~(microformats : Extract_microformats.h_card option)
    ~(json_ld : Extract_json_ld.person option) ~(rel_me : string list)
    ~(feeds : Types.Feed.t list) : t =
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
  let bio =
    match microformats with
    | Some mf -> mf.note
    | None -> None
  in
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
  let social_profiles = Merge.classify_profiles ~email ~social_profiles:raw_profiles in
  { name; url; email; photo; bio; location; feeds; social_profiles }

let extract ~url ~html =
  let base_url = Uri.of_string url in
  let soup = Soup.parse html in
  let feeds = Extract_feeds.extract ~base_url soup in
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
  match Fetch.fetch_html ~sw ~env url with
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
