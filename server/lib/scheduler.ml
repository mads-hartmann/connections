module Log = (val Logs.src_log (Logs.Src.create "scheduler") : Logs.LOG)

(* Configuration *)
let fetch_interval_seconds = 3600.0 (* 1 hour *)

(* State for graceful shutdown *)
let running = ref true
let stop () = running := false

(* Main scheduler loop *)
let rec run_loop ~sw ~env ~clock () =
  if not !running then ()
  else (
    (try Feed_fetcher.fetch_all_feeds ~sw ~env ()
     with exn ->
       Log.err (fun m -> m "Scheduler error: %s" (Printexc.to_string exn)));
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

(* Start the scheduler as a daemon fiber - runs in background *)
let start ~sw ~env =
  let clock = Eio.Stdenv.clock env in
  Log.info (fun m ->
      m "Starting RSS feed scheduler (interval: %g seconds)"
        fetch_interval_seconds);
  running := true;
  (* Fork a daemon fiber that runs the scheduler loop *)
  Eio.Fiber.fork_daemon ~sw (fun () ->
      (* Brief delay for server startup *)
      Eio.Time.sleep clock 5.0;
      run_loop ~sw ~env ~clock ();
      (* Return `Stop_daemon when done *)
      `Stop_daemon)
