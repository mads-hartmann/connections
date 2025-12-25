(* Extract Microformats2 data (h-card, h-entry, rel-me) *)

type h_card = {
  name : string option;
  url : string option;
  photo : string option;
  email : string option;
  note : string option;
  locality : string option;
  country : string option;
}

type h_entry = {
  name : string option;
  summary : string option;
  published : string option;
  updated : string option;
  author : h_card option;
  categories : string list;
}

type t = { cards : h_card list; entries : h_entry list; rel_me : string list }

let empty_card =
  {
    name = None;
    url = None;
    photo = None;
    email = None;
    note = None;
    locality = None;
    country = None;
  }

let empty_entry =
  {
    name = None;
    summary = None;
    published = None;
    updated = None;
    author = None;
    categories = [];
  }

let empty = { cards = []; entries = []; rel_me = [] }

(* Check if element has a specific class *)
let has_class cls node =
  match Soup.attribute "class" node with
  | None -> false
  | Some classes ->
      String.split_on_char ' ' classes |> List.exists (String.equal cls)

(* Find first child element with class *)
let find_class cls node =
  Soup.descendants node |> Soup.elements
  |> Soup.filter (has_class cls)
  |> Soup.first

(* Find all child elements with class *)
let find_all_class cls node =
  Soup.descendants node |> Soup.elements |> Soup.filter (has_class cls)

(* Extract p-* property (plain text) *)
let extract_p_property cls node =
  Option.bind (find_class cls node) (fun el ->
      let text = Soup.trimmed_texts el |> String.concat " " in
      if String.length text > 0 then Some text else None)

(* Extract u-* property (URL) *)
let extract_u_property ~base_url cls node =
  Option.bind (find_class cls node) (fun el ->
      (* Try href first (for links), then src (for images), then text content *)
      let url =
        match Soup.attribute "href" el with
        | Some href -> Some href
        | None -> (
            match Soup.attribute "src" el with
            | Some src -> Some src
            | None ->
                let text = Soup.trimmed_texts el |> String.concat "" in
                if String.length text > 0 then Some text else None)
      in
      Option.map (Util.resolve_url ~base_url) url)

(* Extract dt-* property (datetime) *)
let extract_dt_property cls node =
  Option.bind (find_class cls node) (fun el ->
      (* Try datetime attribute first, then title, then text *)
      match Soup.attribute "datetime" el with
      | Some dt -> Some dt
      | None -> (
          match Soup.attribute "title" el with
          | Some t -> Some t
          | None ->
              let text = Soup.trimmed_texts el |> String.concat "" in
              if String.length text > 0 then Some text else None))

(* Extract all p-category values *)
let extract_categories node =
  find_all_class "p-category" node
  |> Soup.to_list
  |> List.filter_map (fun el ->
      let text = Soup.trimmed_texts el |> String.concat " " in
      if String.length text > 0 then Some text else None)

(* Parse an h-card element *)
let parse_h_card ~base_url node : h_card =
  {
    name = extract_p_property "p-name" node;
    url = extract_u_property ~base_url "u-url" node;
    photo = extract_u_property ~base_url "u-photo" node;
    email = extract_u_property ~base_url "u-email" node;
    note = extract_p_property "p-note" node;
    locality = extract_p_property "p-locality" node;
    country = extract_p_property "p-country-name" node;
  }

(* Parse an h-entry element *)
let parse_h_entry ~base_url node : h_entry =
  let author =
    Option.map (parse_h_card ~base_url) (find_class "p-author" node)
  in
  {
    name = extract_p_property "p-name" node;
    summary = extract_p_property "p-summary" node;
    published = extract_dt_property "dt-published" node;
    updated = extract_dt_property "dt-updated" node;
    author;
    categories = extract_categories node;
  }

(* Extract rel-me links *)
let extract_rel_me ~base_url soup =
  Soup.select "a[rel~=me]" soup
  |> Soup.to_list
  |> List.filter_map (fun node ->
      Option.map (Util.resolve_url ~base_url) (Soup.attribute "href" node))

let extract ~base_url soup : t =
  let cards =
    Soup.select ".h-card" soup |> Soup.to_list
    |> List.map (parse_h_card ~base_url)
  in
  let entries =
    Soup.select ".h-entry" soup
    |> Soup.to_list
    |> List.map (parse_h_entry ~base_url)
  in
  let rel_me = extract_rel_me ~base_url soup in
  { cards; entries; rel_me }
