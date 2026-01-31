(** Scheduled URI metadata fetching. *)

module Log =
  (val Logs.src_log (Logs.Src.create "cron.uri_metadata") : Logs.LOG)

let batch_size = 50
let fetch_interval_seconds = 300.0 (* 5 minutes *)

let fetch_for_uri ~sw ~env (uri : Model.Uri_entry.t) :
    (Model.Uri_entry.t option, Caqti_error.t) result =
  let uri_id = Model.Uri_entry.id uri in
  let uri_url = Model.Uri_entry.url uri in
  Log.info (fun m ->
      m "Fetching metadata for URI %d: %s" uri_id uri_url);
  let og_title, og_description, og_image, og_site_name, og_fetch_error =
    match Metadata.Article.fetch ~sw ~env uri_url with
    | Ok meta ->
        (meta.title, meta.description, meta.image, meta.site_name, None)
    | Error err ->
        Log.warn (fun m ->
            m "Failed to fetch metadata for URI %d: %s" uri_id err);
        (None, None, None, None, Some err)
  in
  Db.Uri_store.update_og_metadata ~id:uri_id ~og_title ~og_description
    ~og_image ~og_site_name ~og_fetch_error

let process_batch ~sw ~env () : int =
  match Db.Uri_store.list_needing_og_metadata ~limit:batch_size with
  | Error err ->
      Log.err (fun m ->
          m "Failed to list URIs needing metadata: %a" Caqti_error.pp err);
      0
  | Ok uris ->
      let count = List.length uris in
      if count > 0 then
        Log.info (fun m -> m "Processing %d URIs for metadata" count);
      List.iter
        (fun uri ->
          match fetch_for_uri ~sw ~env uri with
          | Ok _ -> ()
          | Error err ->
              Log.err (fun m ->
                  m "Failed to update metadata for URI %d: %a"
                    (Model.Uri_entry.id uri) Caqti_error.pp err))
        uris;
      count

let running = ref true
let stop () = running := false

let rec run_loop ~sw ~env ~clock () =
  if not !running then ()
  else (
    (try
       let processed = process_batch ~sw ~env () in
       if processed > 0 then
         Log.info (fun m ->
             m "URI metadata fetch complete: %d URIs" processed)
     with exn ->
       Log.err (fun m ->
           m "URI metadata error: %s" (Printexc.to_string exn)));
    let rec interruptible_sleep remaining =
      if (not !running) || remaining <= 0.0 then ()
      else
        let sleep_time = min 1.0 remaining in
        Eio.Time.sleep clock sleep_time;
        interruptible_sleep (remaining -. sleep_time)
    in
    interruptible_sleep fetch_interval_seconds;
    run_loop ~sw ~env ~clock ())

let start ~sw ~env =
  let clock = Eio.Stdenv.clock env in
  Log.info (fun m ->
      m "Starting URI metadata fetcher (interval: %g seconds, batch: %d)"
        fetch_interval_seconds batch_size);
  running := true;
  Eio.Fiber.fork_daemon ~sw (fun () ->
      Eio.Time.sleep clock 10.0;
      run_loop ~sw ~env ~clock ();
      `Stop_daemon)
