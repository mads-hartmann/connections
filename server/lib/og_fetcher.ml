(* Article metadata fetcher *)

module Log = (val Logs.src_log (Logs.Src.create "og_fetcher") : Logs.LOG)

(* Configuration *)
let batch_size = 50
let fetch_interval_seconds = 300.0 (* 5 minutes *)

(* Fetch metadata for a single article *)
let fetch_for_article ~sw ~env (article : Model.Article.t) :
    (Model.Article.t option, Caqti_error.t) result =
  let article_id = Model.Article.id article in
  let article_url = Model.Article.url article in
  Log.info (fun m ->
      m "Fetching metadata for article %d: %s" article_id article_url);
  let og_input =
    match Url_metadata.Article_metadata.fetch ~sw ~env article_url with
    | Ok meta ->
        {
          Db.Article.og_title = meta.title;
          og_description = meta.description;
          og_image = meta.image;
          og_site_name = meta.site_name;
          og_fetch_error = None;
        }
    | Error err ->
        Log.warn (fun m ->
            m "Failed to fetch metadata for article %d: %s" article_id err);
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
                    (Model.Article.id article) Caqti_error.pp err))
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
         Log.info (fun m -> m "Article metadata fetch complete: %d articles" processed)
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
      m "Starting article metadata fetcher (interval: %g seconds, batch: %d)"
        fetch_interval_seconds batch_size);
  running := true;
  Eio.Fiber.fork_daemon ~sw (fun () ->
      (* Brief delay for server startup *)
      Eio.Time.sleep clock 10.0;
      run_loop ~sw ~env ~clock ();
      `Stop_daemon)
