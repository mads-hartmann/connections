module Log = (val Logs.src_log (Logs.Src.create "scheduler") : Logs.LOG)

(* Configuration *)
let feed_fetch_interval_seconds = 3600.0 (* 1 hour *)
let metadata_refresh_interval_seconds = 3600.0 (* 1 hour *)
let metadata_stale_after_hours = 24
let metadata_refresh_batch_size = 10

(* State for graceful shutdown *)
let running = ref true
let stop () = running := false

(* Interruptible sleep that checks running flag *)
let interruptible_sleep ~clock remaining =
  let rec loop remaining =
    if (not !running) || remaining <= 0.0 then ()
    else
      let sleep_time = min 1.0 remaining in
      Eio.Time.sleep clock sleep_time;
      loop (remaining -. sleep_time)
  in
  loop remaining

(* Refresh metadata for persons that need it *)
let refresh_person_metadata ~sw ~env () =
  Log.info (fun m -> m "Starting person metadata refresh job");
  let stale_threshold =
    let now = Unix.gettimeofday () in
    let threshold = now -. (float_of_int metadata_stale_after_hours *. 3600.0) in
    let tm = Unix.gmtime threshold in
    Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
      (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
  in
  match
    Service.Person.list_needing_metadata_refresh ~older_than:stale_threshold
      ~limit:metadata_refresh_batch_size
  with
  | Error err ->
      Log.err (fun m ->
          m "Failed to list persons needing refresh: %a" Service.Person.Error.pp
            err)
  | Ok persons ->
      Log.info (fun m ->
          m "Found %d persons needing metadata refresh" (List.length persons));
      List.iter
        (fun (person : Model.Person.t) ->
          Log.debug (fun m ->
              m "Refreshing metadata for person %d (%s)" person.id person.name);
          match Service.Person.refresh_metadata ~sw ~env ~id:person.id with
          | Ok _ ->
              Log.debug (fun m ->
                  m "Successfully refreshed metadata for person %d" person.id)
          | Error err ->
              Log.warn (fun m ->
                  m "Failed to refresh metadata for person %d: %a" person.id
                    Service.Person.Error.pp err))
        persons

(* Feed fetch scheduler loop *)
let rec feed_fetch_loop ~sw ~env ~clock () =
  if not !running then ()
  else (
    (try Feed_fetcher.fetch_all_feeds ~sw ~env ()
     with exn ->
       Log.err (fun m ->
           m "Feed fetch scheduler error: %s" (Printexc.to_string exn)));
    interruptible_sleep ~clock feed_fetch_interval_seconds;
    feed_fetch_loop ~sw ~env ~clock ())

(* Metadata refresh scheduler loop *)
let rec metadata_refresh_loop ~sw ~env ~clock () =
  if not !running then ()
  else (
    (try refresh_person_metadata ~sw ~env ()
     with exn ->
       Log.err (fun m ->
           m "Metadata refresh scheduler error: %s" (Printexc.to_string exn)));
    interruptible_sleep ~clock metadata_refresh_interval_seconds;
    metadata_refresh_loop ~sw ~env ~clock ())

(* Start the schedulers as daemon fibers - runs in background *)
let start ~sw ~env =
  let clock = Eio.Stdenv.clock env in
  running := true;

  (* Feed fetch scheduler *)
  Log.info (fun m ->
      m "Starting RSS feed scheduler (interval: %g seconds)"
        feed_fetch_interval_seconds);
  Eio.Fiber.fork_daemon ~sw (fun () ->
      Eio.Time.sleep clock 5.0;
      feed_fetch_loop ~sw ~env ~clock ();
      `Stop_daemon);

  (* Metadata refresh scheduler *)
  Log.info (fun m ->
      m "Starting metadata refresh scheduler (interval: %g seconds)"
        metadata_refresh_interval_seconds);
  Eio.Fiber.fork_daemon ~sw (fun () ->
      Eio.Time.sleep clock 10.0;
      metadata_refresh_loop ~sw ~env ~clock ();
      `Stop_daemon)
