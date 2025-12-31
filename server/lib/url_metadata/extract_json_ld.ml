(* Extract JSON-LD / Schema.org structured data *)

type person = {
  name : string option;
  url : string option;
  image : string option;
  email : string option;
  job_title : string option;
  same_as : string list;
}

type article = {
  headline : string option;
  author : person option;
  date_published : string option;
  date_modified : string option;
  description : string option;
  image : string option;
}

type extracted = {
  persons : person list;
  articles : article list;
  raw : Yojson.Safe.t list;
}

let empty_person =
  {
    name = None;
    url = None;
    image = None;
    email = None;
    job_title = None;
    same_as = [];
  }

let empty_article =
  {
    headline = None;
    author = None;
    date_published = None;
    date_modified = None;
    description = None;
    image = None;
  }

let empty = { persons = []; articles = []; raw = [] }

(* JSON helpers *)
let get_string key json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt key fields with
      | Some (`String s) -> Some s
      | _ -> None)
  | _ -> None

let get_string_or_first_string key json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt key fields with
      | Some (`String s) -> Some s
      | Some (`List (`String s :: _)) -> Some s
      | _ -> None)
  | _ -> None

let get_string_list key json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt key fields with
      | Some (`List items) ->
          List.filter_map (function `String s -> Some s | _ -> None) items
      | Some (`String s) -> [ s ]
      | _ -> [])
  | _ -> []

let get_object key json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt key fields with
      | Some (`Assoc _ as obj) -> Some obj
      | _ -> None)
  | _ -> None

let get_type json =
  match get_string "@type" json with
  | Some t -> Some t
  | None -> get_string_or_first_string "type" json

(* Extract image URL from various formats *)
let extract_image json =
  match get_string "image" json with
  | Some url -> Some url
  | None -> (
      match get_object "image" json with
      | Some img -> get_string "url" img
      | None -> (
          match json with
          | `Assoc fields -> (
              match List.assoc_opt "image" fields with
              | Some (`List (`String url :: _)) -> Some url
              | Some (`List ((`Assoc _ as img) :: _)) -> get_string "url" img
              | _ -> None)
          | _ -> None))

(* Parse a Person object *)
let parse_person json : person =
  {
    name = get_string "name" json;
    url = get_string "url" json;
    image = extract_image json;
    email = get_string "email" json;
    job_title = get_string "jobTitle" json;
    same_as = get_string_list "sameAs" json;
  }

(* Parse author field which can be a string, object, or array *)
let parse_author json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt "author" fields with
      | Some (`String name) -> Some { empty_person with name = Some name }
      | Some (`Assoc _ as author_obj) -> Some (parse_person author_obj)
      | Some (`List ((`Assoc _ as author_obj) :: _)) ->
          Some (parse_person author_obj)
      | Some (`List (`String name :: _)) ->
          Some { empty_person with name = Some name }
      | _ -> None)
  | _ -> None

(* Parse an Article/BlogPosting/NewsArticle object *)
let parse_article json : article =
  {
    headline = get_string "headline" json;
    author = parse_author json;
    date_published = get_string "datePublished" json;
    date_modified = get_string "dateModified" json;
    description = get_string "description" json;
    image = extract_image json;
  }

(* Check if type matches any article type *)
let is_article_type = function
  | "Article" | "BlogPosting" | "NewsArticle" | "WebPage" | "TechArticle"
  | "ScholarlyArticle" | "SocialMediaPosting" ->
      true
  | _ -> false

(* Check if type matches person *)
let is_person_type = function "Person" | "Organization" -> true | _ -> false

(* Process a single JSON-LD object *)
let process_object json (persons, articles) =
  match get_type json with
  | Some t when is_person_type t -> (parse_person json :: persons, articles)
  | Some t when is_article_type t -> (persons, parse_article json :: articles)
  | _ -> (persons, articles)

(* Process JSON-LD which may contain @graph array *)
let process_json_ld json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt "@graph" fields with
      | Some (`List items) -> List.fold_right process_object items ([], [])
      | _ -> process_object json ([], []))
  | `List items -> List.fold_right process_object items ([], [])
  | _ -> ([], [])

let extract soup : extracted =
  let scripts =
    Soup.select "script[type='application/ld+json']" soup |> Soup.to_list
  in
  let parse_script node =
    let text = Soup.trimmed_texts node |> String.concat "" in
    try Some (Yojson.Safe.from_string text) with _ -> None
  in
  let raw = List.filter_map parse_script scripts in
  let persons, articles =
    List.fold_left
      (fun (ps, as_) json ->
        let new_ps, new_as = process_json_ld json in
        (new_ps @ ps, new_as @ as_))
      ([], []) raw
  in
  { persons = List.rev persons; articles = List.rev articles; raw }

let pp_person fmt p =
  Format.fprintf fmt "{ name = %a; url = %a }"
    (Format.pp_print_option Format.pp_print_string)
    p.name
    (Format.pp_print_option Format.pp_print_string)
    p.url

let equal_person a b =
  Option.equal String.equal a.name b.name
  && Option.equal String.equal a.url b.url
  && Option.equal String.equal a.image b.image
  && Option.equal String.equal a.email b.email
  && Option.equal String.equal a.job_title b.job_title
  && List.equal String.equal a.same_as b.same_as

let pp_article fmt a =
  Format.fprintf fmt "{ headline = %a; author = %a }"
    (Format.pp_print_option Format.pp_print_string)
    a.headline
    (Format.pp_print_option pp_person)
    a.author

let equal_article a b =
  Option.equal String.equal a.headline b.headline
  && Option.equal equal_person a.author b.author
  && Option.equal String.equal a.date_published b.date_published
  && Option.equal String.equal a.date_modified b.date_modified
  && Option.equal String.equal a.description b.description
  && Option.equal String.equal a.image b.image

let pp fmt t =
  Format.fprintf fmt "{ persons = [%d]; articles = [%d]; raw = [%d] }"
    (List.length t.persons) (List.length t.articles) (List.length t.raw)

let equal a b =
  List.equal equal_person a.persons b.persons
  && List.equal equal_article a.articles b.articles
