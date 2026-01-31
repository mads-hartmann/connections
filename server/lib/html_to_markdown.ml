(* HTML to Markdown conversion with content extraction *)

module Content_extractor = struct
  (* Score an element based on how many semantic content elements it contains *)
  let score_element node =
    let selectors =
      [ "p"; "h1"; "h2"; "h3"; "h4"; "h5"; "h6"; "blockquote"; "pre"; "ul"; "ol"; "figure"; "img" ]
    in
    List.fold_left
      (fun acc selector ->
        acc + (Soup.select selector node |> Soup.count))
      0 selectors

  (* Check if text contains the title (case-insensitive) *)
  let text_contains_title ~title text =
    let title_lower = String.lowercase_ascii title in
    let text_lower = String.lowercase_ascii text in
    String.length title_lower > 0 && 
    try
      let _ = Str.search_forward (Str.regexp_string title_lower) text_lower 0 in
      true
    with Not_found -> false

  (* Find element containing the article title *)
  let find_title_element ~title soup =
    let title_lower = String.lowercase_ascii title in
    (* Try h1 first, then h2 *)
    let candidates =
      List.concat_map
        (fun selector -> Soup.select selector soup |> Soup.to_list)
        [ "h1"; "h2"; "title" ]
    in
    List.find_opt
      (fun el ->
        let text = Soup.texts el |> String.concat " " |> String.trim in
        let text_lower = String.lowercase_ascii text in
        text_lower = title_lower || text_contains_title ~title text)
      candidates

  (* Traverse up to find a good content container *)
  let find_content_container_from_title title_el =
    let rec find_best_parent node depth =
      if depth > 5 then None
      else
        match Soup.parent node with
        | None -> None
        | Some parent ->
            let score = score_element parent in
            (* If parent has good content density, use it *)
            if score >= 3 then Some parent
            else find_best_parent parent (depth + 1)
    in
    find_best_parent title_el 0

  (* Try common content selectors *)
  let try_common_selectors soup =
    let selectors =
      [
        "article";
        "main";
        "[role=main]";
        ".post-content";
        ".article-content";
        ".entry-content";
        ".content-body";
        ".story-body";
        ".post-body";
        ".article-body";
        "#content";
        "#article";
        "#post";
        ".content";
        ".post";
        ".article";
      ]
    in
    List.find_map (fun sel -> Soup.select_one sel soup) selectors

  (* Remove unwanted elements from content *)
  let clean_content node =
    let unwanted =
      [
        "script"; "style"; "nav"; "footer"; "header"; "aside";
        "iframe"; "noscript"; ".advertisement"; ".ads"; ".social-share";
        ".comments"; ".related-posts"; ".sidebar"; "[role=navigation]";
        "[role=banner]"; "[role=contentinfo]";
      ]
    in
    List.iter
      (fun sel ->
        Soup.select sel node
        |> Soup.iter (fun el -> Soup.delete el))
      unwanted

  (* Extract main content from HTML *)
  let extract ~title html =
    let soup = Soup.parse html in
    (* Try common selectors first *)
    let content_node =
      match try_common_selectors soup with
      | Some node -> Some node
      | None ->
          (* Fallback: find title element and traverse up *)
          Option.bind (find_title_element ~title soup) (fun title_el ->
              find_content_container_from_title title_el)
    in
    match content_node with
    | Some node ->
        clean_content node;
        node
    | None ->
        (* Last resort: use body or entire document *)
        clean_content soup;
        (match Soup.select_one "body" soup with
        | Some body -> body
        | None ->
            (* Create a wrapper element for the soup contents *)
            match Soup.select_one "html" soup with
            | Some html -> html
            | None ->
                (* Parse as a div wrapper *)
                let html_str = Soup.to_string soup in
                let wrapped = Soup.parse ("<div>" ^ html_str ^ "</div>") in
                Option.get (Soup.select_one "div" wrapped))
end

module Converter = struct
  let escape_markdown_chars s =
    (* Only escape characters that would create unintended formatting *)
    s

  let rec convert_element el =
    let tag = Soup.name el |> String.lowercase_ascii in
    let children_md () =
      Soup.children el
      |> Soup.fold (fun acc child -> acc ^ convert_child child) ""
    in
    match tag with
    | "h1" -> "\n# " ^ String.trim (children_md ()) ^ "\n\n"
    | "h2" -> "\n## " ^ String.trim (children_md ()) ^ "\n\n"
    | "h3" -> "\n### " ^ String.trim (children_md ()) ^ "\n\n"
    | "h4" -> "\n#### " ^ String.trim (children_md ()) ^ "\n\n"
    | "h5" -> "\n##### " ^ String.trim (children_md ()) ^ "\n\n"
    | "h6" -> "\n###### " ^ String.trim (children_md ()) ^ "\n\n"
    | "p" -> "\n" ^ String.trim (children_md ()) ^ "\n\n"
    | "br" -> "\n"
    | "hr" -> "\n---\n\n"
    | "strong" | "b" -> "**" ^ children_md () ^ "**"
    | "em" | "i" -> "*" ^ children_md () ^ "*"
    | "code" ->
        let content = children_md () in
        if String.contains content '\n' then
          "\n```\n" ^ content ^ "\n```\n"
        else "`" ^ content ^ "`"
    | "pre" ->
        let content =
          match Soup.select_one "code" el with
          | Some code_el ->
              Soup.texts code_el |> String.concat ""
          | None -> Soup.texts el |> String.concat ""
        in
        "\n```\n" ^ String.trim content ^ "\n```\n\n"
    | "blockquote" ->
        let content = children_md () in
        let lines = String.split_on_char '\n' content in
        let quoted =
          List.map (fun line -> "> " ^ String.trim line) lines
          |> String.concat "\n"
        in
        "\n" ^ quoted ^ "\n\n"
    | "a" ->
        let href = Soup.attribute "href" el |> Option.value ~default:"" in
        let text = String.trim (children_md ()) in
        if String.length text = 0 then ""
        else if String.length href = 0 then text
        else "[" ^ text ^ "](" ^ href ^ ")"
    | "img" ->
        let src = Soup.attribute "src" el |> Option.value ~default:"" in
        let alt = Soup.attribute "alt" el |> Option.value ~default:"" in
        if String.length src = 0 then ""
        else "![" ^ alt ^ "](" ^ src ^ ")"
    | "ul" ->
        let items =
          Soup.children el
          |> Soup.elements
          |> Soup.filter (fun child -> Soup.name child = "li")
          |> Soup.fold
               (fun acc li ->
                 let content = String.trim (convert_element li) in
                 acc ^ "- " ^ content ^ "\n")
               ""
        in
        "\n" ^ items ^ "\n"
    | "ol" ->
        let items =
          Soup.children el
          |> Soup.elements
          |> Soup.filter (fun child -> Soup.name child = "li")
          |> Soup.fold
               (fun (acc, i) li ->
                 let content = String.trim (convert_element li) in
                 (acc ^ string_of_int i ^ ". " ^ content ^ "\n", i + 1))
               ("", 1)
          |> fst
        in
        "\n" ^ items ^ "\n"
    | "li" -> children_md ()
    | "figure" ->
        (* Handle figure with img and figcaption *)
        let img_md =
          match Soup.select_one "img" el with
          | Some img -> convert_element img
          | None -> ""
        in
        let caption =
          match Soup.select_one "figcaption" el with
          | Some cap -> "\n*" ^ String.trim (Soup.texts cap |> String.concat " ") ^ "*"
          | None -> ""
        in
        "\n" ^ img_md ^ caption ^ "\n\n"
    | "figcaption" -> "" (* Handled by figure *)
    | "table" -> convert_table el
    | "div" | "section" | "article" | "main" | "span" -> children_md ()
    | "script" | "style" | "nav" | "footer" | "header" | "aside" | "noscript" -> ""
    | _ -> children_md ()

  and convert_child child =
    match Soup.element child with
    | None ->
        (* Text node *)
        let text = Soup.leaf_text child |> Option.value ~default:"" in
        escape_markdown_chars text
    | Some el -> convert_element el

  and convert_table el =
    let rows = Soup.select "tr" el |> Soup.to_list in
    match rows with
    | [] -> ""
    | header_row :: data_rows ->
        let cells_of_row row =
          Soup.select "th, td" row
          |> Soup.to_list
          |> List.map (fun cell ->
                 String.trim (Soup.texts cell |> String.concat " "))
        in
        let header_cells = cells_of_row header_row in
        let col_count = List.length header_cells in
        if col_count = 0 then ""
        else
          let header_line = "| " ^ String.concat " | " header_cells ^ " |" in
          let separator = "| " ^ String.concat " | " (List.init col_count (fun _ -> "---")) ^ " |" in
          let data_lines =
            List.map
              (fun row ->
                let cells = cells_of_row row in
                (* Pad with empty cells if needed *)
                let padded =
                  if List.length cells < col_count then
                    cells @ List.init (col_count - List.length cells) (fun _ -> "")
                  else cells
                in
                "| " ^ String.concat " | " padded ^ " |")
              data_rows
          in
          "\n" ^ header_line ^ "\n" ^ separator ^ "\n"
          ^ String.concat "\n" data_lines ^ "\n\n"

  let convert el =
    let raw = convert_element el in
    (* Clean up excessive whitespace *)
    let lines = String.split_on_char '\n' raw in
    let cleaned =
      List.fold_left
        (fun (acc, prev_empty) line ->
          let trimmed = String.trim line in
          let is_empty = String.length trimmed = 0 in
          match (is_empty, prev_empty) with
          | true, true -> (acc, true) (* Skip consecutive empty lines *)
          | true, false -> (acc @ [ "" ], true)
          | false, _ -> (acc @ [ trimmed ], false))
        ([], false) lines
      |> fst
    in
    String.concat "\n" cleaned |> String.trim
end

let convert ~title html =
  let content_node = Content_extractor.extract ~title html in
  Converter.convert content_node
