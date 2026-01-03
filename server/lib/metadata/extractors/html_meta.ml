(* Extract standard HTML meta tags *)

type t = {
  title : string option;
  description : string option;
  author : string option;
  canonical : string option;
  favicon : string option;
  webmention : string option;
}

let empty =
  {
    title = None;
    description = None;
    author = None;
    canonical = None;
    favicon = None;
    webmention = None;
  }

let extract_meta_content name soup =
  let selector = Printf.sprintf "meta[name=%s]" name in
  Html_helpers.select_attr selector "content" soup

let extract_link_href rel soup =
  let selector = Printf.sprintf "link[rel=%s]" rel in
  Html_helpers.select_attr selector "href" soup

let extract_favicon ~base_url soup =
  (* Try multiple favicon link relations *)
  let selectors = [ "link[rel=icon]"; "link[rel='shortcut icon']" ] in
  let rec try_selectors = function
    | [] -> None
    | sel :: rest -> (
        match Html_helpers.select_attr sel "href" soup with
        | Some href -> Some (Html_helpers.resolve_url ~base_url href)
        | None -> try_selectors rest)
  in
  try_selectors selectors

let extract ~base_url soup : t =
  let title = Html_helpers.select_text "title" soup in
  let description = extract_meta_content "description" soup in
  let author = extract_meta_content "author" soup in
  let canonical =
    Option.map
      (Html_helpers.resolve_url ~base_url)
      (extract_link_href "canonical" soup)
  in
  let favicon = extract_favicon ~base_url soup in
  let webmention =
    Option.map
      (Html_helpers.resolve_url ~base_url)
      (extract_link_href "webmention" soup)
  in
  { title; description; author; canonical; favicon; webmention }

let pp fmt t =
  Format.fprintf fmt "{ title = %a; description = %a; author = %a }"
    (Format.pp_print_option Format.pp_print_string)
    t.title
    (Format.pp_print_option Format.pp_print_string)
    t.description
    (Format.pp_print_option Format.pp_print_string)
    t.author

let equal a b =
  Option.equal String.equal a.title b.title
  && Option.equal String.equal a.description b.description
  && Option.equal String.equal a.author b.author
  && Option.equal String.equal a.canonical b.canonical
  && Option.equal String.equal a.favicon b.favicon
  && Option.equal String.equal a.webmention b.webmention
