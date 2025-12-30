(* Open Graph metadata fetcher for articles *)

module Log = (val Logs.src_log (Logs.Src.create "og_fetcher") : Logs.LOG)

(* Configuration *)
let batch_size = 50
let fetch_interval_seconds = 300.0 (* 5 minutes *)

(* Maximum number of redirects to follow *)
let max_redirects = 10

(* Check if status is a redirect *)
let is_redirect status =
  let code = Piaf.Status.to_code status in
  code = 301 || code = 302 || code = 303 || code = 307 || code = 308

(* Get redirect location from response headers *)
let get_redirect_location ~base_uri response =
  Piaf.Headers.get response.Piaf.Response.headers "location"
  |> Option.map (fun loc ->
         let loc_uri = Uri.of_string loc in
         match Uri.host loc_uri with
         | None | Some "" -> Uri.resolve "" base_uri loc_uri
         | Some _ -> loc_uri)

(* Fetch URL content using Piaf with redirect following *)
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

(* Extract OG metadata from HTML *)
let extract_og_metadata html : Db.Article.og_metadata_input =
  let soup = Soup.parse html in
  let og = Url_metadata.Extract_opengraph.extract soup in
  {
    Db.Article.og_title = og.title;
    og_description = og.description;
    og_image = og.image;
    og_site_name = og.site_name;
    og_fetch_error = None;
  }

(* Fetch OG metadata for a single article *)
let fetch_for_article ~sw ~env (article : Model.Article.t) :
    (Model.Article.t option, Caqti_error.t) result =
  let article_id = Model.Article.id article in
  let article_url = Model.Article.url article in
  Log.info (fun m -> m "Fetching OG metadata for article %d: %s" article_id article_url);
  let og_input =
    match fetch_html ~sw ~env article_url with
    | Ok html -> extract_og_metadata html
    | Error err ->
        Log.warn (fun m ->
            m "Failed to fetch OG for article %d: %s" article_id err);
        {
          Db.Article.og_title = None;
          og_description = None;
          og_image = None;
          og_site_name = None;
          og_fetch_error = Some err;
        }
  in
  Db.Article.update_og_metadata ~id:article_id og_input

(* Process a batch of articles needing OG fetch *)
let process_batch ~sw ~env () : int =
  match Db.Article.list_needing_og_fetch ~limit:batch_size with
  | Error err ->
      Log.err (fun m ->
          m "Failed to list articles needing OG fetch: %a" Caqti_error.pp err);
      0
  | Ok articles ->
      let count = List.length articles in
      if count > 0 then
        Log.info (fun m -> m "Processing %d articles for OG metadata" count);
      List.iter
        (fun article ->
          match fetch_for_article ~sw ~env article with
          | Ok _ -> ()
          | Error err ->
              Log.err (fun m ->
                  m "Failed to update OG metadata for article %d: %a"
                    (Model.Article.id article)
                    Caqti_error.pp err))
        articles;
      count

(* State for graceful shutdown *)
let running = ref true
let stop () = running := false

(* Main scheduler loop for OG fetching *)
let rec run_loop ~sw ~env ~clock () =
  if not !running then ()
  else (
    (try
       let processed = process_batch ~sw ~env () in
       if processed > 0 then
         Log.info (fun m -> m "OG fetch batch complete: %d articles" processed)
     with exn ->
       Log.err (fun m -> m "OG fetcher error: %s" (Printexc.to_string exn)));
    (* Sleep, checking running flag periodically for faster shutdown *)
    let rec interruptible_sleep remaining =
      if (not !running) || remaining <= 0.0 then ()
      else
        let sleep_time = min 1.0 remaining in
        Eio.Time.sleep clock sleep_time;
        interruptible_sleep (remaining -. sleep_time)
    in
    interruptible_sleep fetch_interval_seconds;
    run_loop ~sw ~env ~clock ())

(* Start the OG fetcher as a daemon fiber *)
let start ~sw ~env =
  let clock = Eio.Stdenv.clock env in
  Log.info (fun m ->
      m "Starting OG metadata fetcher (interval: %g seconds, batch: %d)"
        fetch_interval_seconds batch_size);
  running := true;
  Eio.Fiber.fork_daemon ~sw (fun () ->
      (* Brief delay for server startup *)
      Eio.Time.sleep clock 10.0;
      run_loop ~sw ~env ~clock ();
      `Stop_daemon)
