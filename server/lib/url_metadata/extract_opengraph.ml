(* Extract Open Graph protocol metadata *)

type t = {
  title : string option;
  og_type : string option;
  url : string option;
  image : string option;
  description : string option;
  site_name : string option;
  locale : string option;
  author : string option;
  published_time : string option;
  modified_time : string option;
  tags : string list;
}

let empty =
  {
    title = None;
    og_type = None;
    url = None;
    image = None;
    description = None;
    site_name = None;
    locale = None;
    author = None;
    published_time = None;
    modified_time = None;
    tags = [];
  }

(* Build a map of property -> content from og: and article: meta tags *)
let build_property_map soup =
  let og_tags = Soup.select "meta[property^='og:']" soup |> Soup.to_list in
  let article_tags =
    Soup.select "meta[property^='article:']" soup |> Soup.to_list
  in
  let extract_pair node =
    match Soup.attribute "property" node, Soup.attribute "content" node with
    | Some prop, Some content -> Some (prop, content)
    | _ -> None
  in
  List.filter_map extract_pair (og_tags @ article_tags)

let find_property props name = List.assoc_opt name props

let find_all_properties props name =
  List.filter_map
    (fun (k, v) -> if String.equal k name then Some v else None)
    props

let extract soup : t =
  let props = build_property_map soup in
  {
    title = find_property props "og:title";
    og_type = find_property props "og:type";
    url = find_property props "og:url";
    image = find_property props "og:image";
    description = find_property props "og:description";
    site_name = find_property props "og:site_name";
    locale = find_property props "og:locale";
    author = find_property props "article:author";
    published_time = find_property props "article:published_time";
    modified_time = find_property props "article:modified_time";
    tags = find_all_properties props "article:tag";
  }
