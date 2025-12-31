(* OPML Parser - extracts feed URLs, titles, and tags from OPML files *)

type feed_entry = { url : string; title : string option; tags : string list }
type parse_result = { feeds : feed_entry list; errors : string list }

(* Extract attribute value from attribute list *)
let get_attr name attrs =
  List.find_map
    (fun ((_, local), value) -> if local = name then Some value else None)
    attrs

(* Skip element and all its children *)
let rec skip_element input =
  match Xmlm.input input with
  | `El_end -> ()
  | `El_start _ ->
      skip_element input;
      skip_element input
  | _ -> skip_element input

(* Parse outline elements recursively, tracking tag path *)
let rec parse_outline ~tags acc input =
  match Xmlm.peek input with
  | `El_end ->
      (* Consume the end tag and return *)
      let _ = Xmlm.input input in
      acc
  | `El_start ((_, "outline"), attrs) ->
      let _ = Xmlm.input input in
      (* consume start tag *)
      let xml_url = get_attr "xmlUrl" attrs in
      let title = get_attr "title" attrs in
      let text = get_attr "text" attrs in
      let display_name = match title with Some t -> Some t | None -> text in
      let acc =
        match xml_url with
        | Some url ->
            (* This is a feed entry - parse any children then continue *)
            let acc = { url; title = display_name; tags } :: acc in
            (* Consume children until we hit the end tag for this outline *)
            parse_outline ~tags acc input
        | None ->
            (* This is a folder - recurse with updated tag path *)
            let tag_name =
              match display_name with Some n -> n | None -> "Unknown"
            in
            let new_tags = tags @ [ tag_name ] in
            parse_outline ~tags:new_tags acc input
      in
      (* Parse siblings *)
      parse_outline ~tags acc input
  | `El_start _ ->
      (* Skip non-outline elements *)
      skip_element input;
      parse_outline ~tags acc input
  | `Data _ ->
      let _ = Xmlm.input input in
      parse_outline ~tags acc input
  | `Dtd _ ->
      let _ = Xmlm.input input in
      parse_outline ~tags acc input

(* Skip to body element - returns true if found, false if end of document *)
let rec skip_to_body input =
  if not (Xmlm.eoi input) then
    match Xmlm.input input with
    | `El_start ((_, "body"), _) -> true
    | _ -> skip_to_body input
  else false

(* Main parse function *)
let parse (content : string) : (parse_result, string) result =
  try
    let input = Xmlm.make_input (`String (0, content)) in
    (* Find body element *)
    if skip_to_body input then
      let feeds = parse_outline ~tags:[] [] input in
      Ok { feeds = List.rev feeds; errors = [] }
    else Error "No body element found in OPML"
  with
  | Xmlm.Error ((line, col), err) ->
      Error
        (Printf.sprintf "XML parse error at line %d, col %d: %s" line col
           (Xmlm.error_message err))
  | exn -> Error (Printf.sprintf "Parse error: %s" (Printexc.to_string exn))
