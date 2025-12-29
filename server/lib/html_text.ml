(* Extract plain text from HTML and generate summaries *)

let max_summary_length = 250

(* Extract plain text from HTML string *)
let extract_text (html : string) : string =
  let soup = Soup.parse html in
  Soup.texts soup |> String.concat " " |> String.trim

(* Normalize whitespace: collapse multiple spaces/newlines into single space *)
let normalize_whitespace (text : string) : string =
  let buf = Buffer.create (String.length text) in
  let prev_space = ref false in
  String.iter
    (fun c ->
      match c with
      | ' ' | '\n' | '\r' | '\t' ->
          if not !prev_space then Buffer.add_char buf ' ';
          prev_space := true
      | _ ->
          Buffer.add_char buf c;
          prev_space := false)
    text;
  Buffer.contents buf |> String.trim

(* Truncate text at word boundary, adding ellipsis if truncated *)
let truncate_at_word_boundary ~max_length (text : string) : string =
  if String.length text <= max_length then text
  else
    let truncated = String.sub text 0 max_length in
    match String.rindex_opt truncated ' ' with
    | Some idx -> String.sub truncated 0 idx ^ "..."
    | None -> truncated ^ "..."

(* Generate a plain text summary from HTML content *)
let generate_summary (html : string) : string =
  html |> extract_text |> normalize_whitespace
  |> truncate_at_word_boundary ~max_length:max_summary_length

(* Convert HTML to plain text summary, or use provided text directly *)
let to_summary ~(html : string option) ~(text : string option) : string option =
  match text with
  | Some t ->
      let normalized = normalize_whitespace t in
      Some (truncate_at_word_boundary ~max_length:max_summary_length normalized)
  | None -> Option.map generate_summary html
