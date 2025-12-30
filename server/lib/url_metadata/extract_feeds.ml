(* Extract RSS/Atom/JSON feed links from HTML *)

let format_of_mime_type mime =
  let mime = String.lowercase_ascii mime in
  if String.equal mime "application/rss+xml" then Some Types.Feed.Rss
  else if String.equal mime "application/atom+xml" then Some Types.Feed.Atom
  else if String.equal mime "application/feed+json" then
    Some Types.Feed.Json_feed
  else if String.equal mime "application/json" then Some Types.Feed.Json_feed
  else None

let extract_feed ~base_url node : Types.Feed.t option =
  let open Option in
  let rel = Soup.attribute "rel" node in
  let type_attr = Soup.attribute "type" node in
  let href = Soup.attribute "href" node in
  match (rel, type_attr, href) with
  | Some rel, Some mime, Some href when String.equal rel "alternate" ->
      bind (format_of_mime_type mime) (fun format ->
          let url = Html_helpers.resolve_url ~base_url href in
          let title = Soup.attribute "title" node in
          Some { Types.Feed.url; title; format })
  | _ -> None

let extract ~base_url soup : Types.Feed.t list =
  Soup.select "link[rel=alternate]" soup
  |> Soup.to_list
  |> List.filter_map (extract_feed ~base_url)
