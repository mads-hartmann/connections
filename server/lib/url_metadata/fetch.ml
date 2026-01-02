module Log = (val Logs.src_log (Logs.Src.create "url_metadata.fetch") : Logs.LOG)

let max_redirects = 10

let is_redirect status =
  let code = Piaf.Status.to_code status in
  code = 301 || code = 302 || code = 303 || code = 307 || code = 308

let get_redirect_location ~base_uri response =
  Piaf.Headers.get response.Piaf.Response.headers "location"
  |> Option.map (fun loc ->
      let loc_uri = Uri.of_string loc in
      match Uri.host loc_uri with
      | None | Some "" -> Uri.resolve "" base_uri loc_uri
      | Some _ -> loc_uri)

let fetch_html ~sw ~env (url : string) : (string, string) result =
  let rec fetch_with_redirects uri remaining_redirects =
    if remaining_redirects <= 0 then Error "Too many redirects"
    else
      try
        match Piaf.Client.Oneshot.get ~sw env uri with
        | Error err ->
            Error (Format.asprintf "Fetch error: %a" Piaf.Error.pp_hum err)
        | Ok response ->
            let status = response.Piaf.Response.status in
            if Piaf.Status.is_successful status then
              match Piaf.Body.to_string response.body with
              | Ok body_str -> Ok body_str
              | Error err ->
                  Error
                    (Format.asprintf "Body read error: %a" Piaf.Error.pp_hum err)
            else if is_redirect status then
              match get_redirect_location ~base_uri:uri response with
              | Some new_uri ->
                  Log.debug (fun m ->
                      m "Following redirect from %s to %s" (Uri.to_string uri)
                        (Uri.to_string new_uri));
                  fetch_with_redirects new_uri (remaining_redirects - 1)
              | None -> Error "Redirect without Location header"
            else Error (Printf.sprintf "HTTP %d" (Piaf.Status.to_code status))
      with exn ->
        Error (Printf.sprintf "Fetch error: %s" (Printexc.to_string exn))
  in
  fetch_with_redirects (Uri.of_string url) max_redirects
