(* Gravatar URL generation and validation *)

let hash_email email =
  let normalized = String.lowercase_ascii (String.trim email) in
  let digest = Digestif.MD5.digest_string normalized in
  Digestif.MD5.to_hex digest

let url_of_email ?(size = 200) email =
  let hash = hash_email email in
  Printf.sprintf "https://gravatar.com/avatar/%s?s=%d&d=404" hash size

let exists ~sw ~env url =
  try
    match Piaf.Client.Oneshot.head ~sw env (Uri.of_string url) with
    | Ok response -> Piaf.Status.is_successful response.status
    | Error _ -> false
  with _ -> false

let validate ~sw ~env email =
  let url = url_of_email email in
  if exists ~sw ~env url then Some url else None
