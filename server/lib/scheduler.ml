open Lwt.Syntax

(* Configuration *)
let fetch_interval_seconds = 3600.0 (* 1 hour *)

(* State for graceful shutdown *)
let running = ref true
let stop () = running := false

(* Sleep that can be interrupted by stop() *)
let rec interruptible_sleep seconds =
  if (not !running) || seconds <= 0.0 then Lwt.return_unit
  else
    let check_interval = 1.0 in
    let sleep_time = min check_interval seconds in
    let* () = Lwt_unix.sleep sleep_time in
    interruptible_sleep (seconds -. sleep_time)

(* Main scheduler loop *)
let rec run_loop () =
  if not !running then Lwt.return_unit
  else
    let* () =
      Lwt.catch
        (fun () -> Feed_fetcher.fetch_all_feeds ())
        (fun exn ->
          Dream.error (fun log ->
              log "Scheduler error: %s" (Printexc.to_string exn));
          Lwt.return_unit)
    in
    (* Sleep, but check running flag periodically for faster shutdown *)
    let* () = interruptible_sleep fetch_interval_seconds in
    run_loop ()

(* Start the scheduler - returns immediately, runs in background *)
let start () =
  Dream.info (fun log ->
      log "Starting RSS feed scheduler (interval: %g seconds)"
        fetch_interval_seconds);
  running := true;
  (* Run first fetch after a brief delay, then continue on interval *)
  Lwt.async (fun () ->
      let* () = Lwt_unix.sleep 5.0 in
      (* Brief delay for server startup *)
      run_loop ())
