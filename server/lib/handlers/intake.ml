open Handler_utils.Syntax

(* Store sw and env for HTTP requests - set by main *)
let sw_ref : Eio.Switch.t option ref = ref None
let env_ref : Eio_unix.Stdenv.base option ref = ref None

let set_context ~sw ~env =
  sw_ref := Some sw;
  env_ref := Some env

let get_context () =
  match (!sw_ref, !env_ref) with
  | Some sw, Some env -> (sw, env)
  | _ -> failwith "Handler context not initialized"

(* Extract domain from URL, returns (subdomain.domain.tld, domain.tld) for fallback *)
let extract_domains url =
  try
    let uri = Uri.of_string url in
    match Uri.host uri with
    | None -> []
    | Some host ->
        let host = String.lowercase_ascii host in
        (* Remove www. prefix if present *)
        let host =
          if String.starts_with ~prefix:"www." host then
            String.sub host 4 (String.length host - 4)
          else host
        in
        let parts = String.split_on_char '.' host in
        match parts with
        | [] -> []
        | [ _ ] -> [ host ]
        | _ ->
            (* For blog.example.com, return [blog.example.com; example.com] *)
            let root_domain =
              let len = List.length parts in
              if len >= 2 then
                String.concat "."
                  [ List.nth parts (len - 2); List.nth parts (len - 1) ]
              else host
            in
            if String.equal host root_domain then [ host ]
            else [ host; root_domain ]
  with _ -> []

(* Build root URL from domain *)
let root_url_of_domain domain = "https://" ^ domain

(* Convert article metadata to JSON *)
let article_metadata_to_json (m : Metadata.Article.t) =
  let opt_field name = function
    | Some v -> [ (name, `String v) ]
    | None -> []
  in
  `Assoc
    (opt_field "title" m.title
    @ opt_field "description" m.description
    @ opt_field "image" m.image
    @ opt_field "published_at" m.published_at
    @ opt_field "author_name" m.author_name
    @ opt_field "site_name" m.site_name
    @ opt_field "canonical_url" m.canonical_url)

(* Convert contact metadata to JSON for proposed_person *)
let contact_metadata_to_json (c : Metadata.Contact.t) =
  let opt_field name = function
    | Some v -> [ (name, `String v) ]
    | None -> []
  in
  let feed_to_json (f : Metadata.Contact.Feed.t) =
    `Assoc
      ([
         ("url", `String f.url);
         ( "format",
           `String
             (match f.format with
             | Metadata.Contact.Feed.Rss -> "rss"
             | Atom -> "atom"
             | Json_feed -> "json_feed") );
       ]
      @ opt_field "title" f.title)
  in
  let profile_to_json (p : Metadata.Contact.Classified_profile.t) =
    `Assoc
      [
        ("url", `String p.url);
        ("field_type", Model.Metadata_field_type.to_json_with_id p.field_type);
      ]
  in
  `Assoc
    (opt_field "name" c.name @ opt_field "photo" c.photo
    @ opt_field "bio" c.bio @ opt_field "location" c.location
    @ [ ("feeds", `List (List.map feed_to_json c.feeds)) ]
    @ [
        ("social_profiles", `List (List.map profile_to_json c.social_profiles));
      ])

let article_intake request =
  let* url =
    Handler_utils.query "url" request
    |> Handler_utils.or_not_found "Missing 'url' query parameter"
  in
  let* valid_url =
    Handler_utils.validate_url url |> Handler_utils.or_bad_request
  in
  let sw, env = get_context () in
  (* Fetch article metadata *)
  let* article_metadata =
    Metadata.Article.fetch ~sw ~env valid_url |> Handler_utils.or_bad_request
  in
  (* Extract domains for person lookup *)
  let domains = extract_domains valid_url in
  (* Try to find existing person by domain *)
  let* existing_person =
    Service.Person.find_by_domain ~domains |> Handler_utils.or_person_error
  in
  (* If no existing person, fetch contact metadata from domain root *)
  let proposed_person =
    match existing_person with
    | Some _ -> None
    | None -> (
        match domains with
        | [] -> None
        | domain :: _ -> (
            let root_url = root_url_of_domain domain in
            match Metadata.Contact.fetch ~sw ~env root_url with
            | Ok contact -> Some contact
            | Error _ -> None))
  in
  (* Build response *)
  let response =
    `Assoc
      ([
         ("url", `String valid_url);
         ("article", article_metadata_to_json article_metadata);
       ]
      @ (match existing_person with
        | Some p -> [ ("person", Model.Person.to_json p) ]
        | None -> [ ("person", `Null) ])
      @ (match proposed_person with
        | Some c -> [ ("proposed_person", contact_metadata_to_json c) ]
        | None -> [ ("proposed_person", `Null) ]))
  in
  Handler_utils.json_response response

let routes () =
  let open Tapak.Router in
  [ get (s "intake" / s "article") |> request |> into article_intake ]
