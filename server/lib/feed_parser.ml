(** RSS and Atom feed parsing utilities. *)

type parsed_feed = Rss2 of Syndic.Rss2.channel | Atom of Syndic.Atom.feed
type metadata = { author : string option; title : string option }

let parse (content : string) : (parsed_feed, string) result =
  let input = Xmlm.make_input (`String (0, content)) in
  try Ok (Rss2 (Syndic.Rss2.parse input))
  with _ -> (
    let input = Xmlm.make_input (`String (0, content)) in
    try Ok (Atom (Syndic.Atom.parse input))
    with exn ->
      Error (Printf.sprintf "Parse error: %s" (Printexc.to_string exn)))

let extract_rss2_author (channel : Syndic.Rss2.channel) : string option =
  match channel.managingEditor with
  | Some editor -> Some editor
  | None -> ( match channel.items with item :: _ -> item.author | [] -> None)

let extract_atom_author (feed : Syndic.Atom.feed) : string option =
  match feed.authors with
  | author :: _ -> Some author.name
  | [] -> (
      match feed.entries with
      | entry :: _ ->
          let first_author, _ = entry.authors in
          Some first_author.name
      | [] -> None)

let extract_title (feed : parsed_feed) : string option =
  match feed with
  | Rss2 channel -> Some channel.title
  | Atom feed -> (
      match feed.title with
      | Syndic.Atom.Text t -> Some t
      | Syndic.Atom.Html (_, t) -> Some t
      | Syndic.Atom.Xhtml _ -> None)

let extract_metadata (feed : parsed_feed) : metadata =
  let author =
    match feed with
    | Rss2 channel -> extract_rss2_author channel
    | Atom feed -> extract_atom_author feed
  in
  let title = extract_title feed in
  { author; title }

let fetch_metadata ~sw ~env (url : string) : (metadata, string) result =
  match Http_client.fetch ~sw ~env url with
  | Error msg -> Error msg
  | Ok content -> (
      match parse content with
      | Error msg -> Error msg
      | Ok parsed_feed -> Ok (extract_metadata parsed_feed))
