(* Update E2E test snapshots by calling each endpoint and saving responses *)

let server_port = 18081

let () =
  (* Ensure snapshots directory exists *)
  if not (Sys.file_exists E2e_helpers.snapshots_dir) then
    Unix.mkdir E2e_helpers.snapshots_dir 0o755;

  Printf.printf "Starting server...\n%!";

  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let proc = E2e_helpers.start_server ~sw ~env ~port:server_port in
  Fun.protect
    ~finally:(fun () ->
      Printf.printf "Stopping server...\n%!";
      E2e_helpers.stop_server proc)
    (fun () ->
      Printf.printf "Server started, updating snapshots...\n%!";
      List.iter
        (fun endpoint ->
          let status, body =
            E2e_helpers.http_get ~env ~sw ~port:server_port endpoint
          in
          if status = 200 then begin
            E2e_helpers.write_snapshot endpoint body;
            Printf.printf "  ✓ %s\n%!" endpoint
          end
          else Printf.printf "  ✗ %s (status %d)\n%!" endpoint status)
        E2e_helpers.endpoints;
      Printf.printf "Done!\n%!")
