(* Resolve a potentially relative URL against a base URL *)
let resolve_url ~base_url href =
  let href_uri = Uri.of_string href in
  match Uri.scheme href_uri with
  | Some _ -> href (* Already absolute *)
  | None -> Uri.to_string (Uri.resolve "" base_url href_uri)

(* Get attribute value from a Soup node *)
let attr name node = Soup.attribute name node

(* Get trimmed text content *)
let trimmed_text node =
  let text = Soup.trimmed_texts node |> String.concat " " in
  if String.length text = 0 then None else Some text

(* Select first matching element and get attribute *)
let select_attr selector attr_name soup =
  Option.bind (Soup.select_one selector soup) (fun n -> attr attr_name n)

(* Select first matching element and get text *)
let select_text selector soup =
  Option.bind (Soup.select_one selector soup) trimmed_text
