(* Extract Twitter/X Card metadata *)

type t = {
  card_type : string option;
  site : string option;
  creator : string option;
  title : string option;
  description : string option;
  image : string option;
}

let empty =
  {
    card_type = None;
    site = None;
    creator = None;
    title = None;
    description = None;
    image = None;
  }

(* Build a map of name -> content from twitter: meta tags *)
let build_property_map soup =
  let tags = Soup.select "meta[name^='twitter:']" soup |> Soup.to_list in
  let extract_pair node =
    match (Soup.attribute "name" node, Soup.attribute "content" node) with
    | Some name, Some content -> Some (name, content)
    | _ -> None
  in
  List.filter_map extract_pair tags

let find_property props name = List.assoc_opt name props

let extract soup : t =
  let props = build_property_map soup in
  {
    card_type = find_property props "twitter:card";
    site = find_property props "twitter:site";
    creator = find_property props "twitter:creator";
    title = find_property props "twitter:title";
    description = find_property props "twitter:description";
    image = find_property props "twitter:image";
  }
