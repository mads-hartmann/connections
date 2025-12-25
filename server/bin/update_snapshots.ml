(* Update E2E test snapshots by calling each endpoint and saving responses *)

let server_port = 18081
let base_url = Printf.sprintf "http://localhost:%d" server_port

let find_workspace_root () =
  let rec find dir =
    let dune_project = Filename.concat dir "dune-project" in
    if Sys.file_exists dune_project then Some dir
    else
      let parent = Filename.dirname dir in
      if parent = dir then None else find parent
  in
  find (Sys.getcwd ())

let workspace_root = match find_workspace_root () with
  | Some root -> root
  | None -> failwith "Could not find workspace root (dune-project)"

let test_db_path = Filename.concat workspace_root "server/test/data/test.db"
let snapshots_dir = Filename.concat workspace_root "server/test/data/snapshots"

(* Endpoints to snapshot *)
let endpoints = [
  "/persons";
  "/persons/8";
  "/feeds";
  "/feeds/2";
  "/articles";
  "/articles/1";
  "/categories";
]

(* Server process management *)
let wait_for_server ~env ~timeout_seconds =
  let net = Eio.Stdenv.net env in
  let clock = Eio.Stdenv.clock env in
  let start_time = Eio.Time.now clock in
  let rec loop () =
    let elapsed = Eio.Time.now clock -. start_time in
    if elapsed > timeout_seconds then
      failwith "Server failed to start within timeout"
    else
      try
        Eio.Net.with_tcp_connect net
          ~host:"127.0.0.1"
          ~service:(string_of_int server_port)
          (fun _flow -> ())
      with _ ->
        Eio.Time.sleep clock 0.1;
        loop ()
  in
  loop ()

let start_server ~sw ~env =
  let executable = Filename.concat workspace_root "_build/default/server/bin/main.exe" in
  if not (Sys.file_exists executable) then
    failwith (Printf.sprintf "Server executable not found: %s. Run 'dune build' first." executable);
  let args = [
    executable;
    "--db"; test_db_path;
    "--port"; string_of_int server_port;
    "--no-scheduler"
  ] in
  let mgr = Eio.Stdenv.process_mgr env in
  let proc = Eio.Process.spawn ~sw mgr args in
  wait_for_server ~env ~timeout_seconds:10.0;
  proc

let stop_server proc =
  Eio.Process.signal proc Sys.sigterm;
  ignore (Eio.Process.await proc)

(* HTTP client *)
let get ~env ~sw path =
  let uri = Uri.of_string (base_url ^ path) in
  let client = Piaf.Client.create ~sw env uri in
  match client with
  | Error err ->
      failwith (Format.asprintf "Failed to create client: %a" Piaf.Error.pp_hum err)
  | Ok client ->
      let response = Piaf.Client.request client ~meth:`GET (Uri.path_and_query uri) in
      match response with
      | Error err ->
          failwith (Format.asprintf "Request failed: %a" Piaf.Error.pp_hum err)
      | Ok response ->
          let body = Piaf.Body.to_string response.body in
          match body with
          | Error err ->
              failwith (Format.asprintf "Failed to read body: %a" Piaf.Error.pp_hum err)
          | Ok body_str ->
              let status = Piaf.Status.to_code response.status in
              (status, body_str)

(* Snapshot helpers *)
let snapshot_path endpoint =
  let name =
    endpoint
    |> String.split_on_char '/'
    |> List.filter (fun s -> s <> "")
    |> String.concat "_"
  in
  Filename.concat snapshots_dir (name ^ ".json")

let format_json str =
  try
    let json = Yojson.Safe.from_string str in
    Yojson.Safe.pretty_to_string json
  with _ -> str

let write_snapshot endpoint body =
  let path = snapshot_path endpoint in
  let formatted = format_json body in
  Out_channel.with_open_text path (fun oc ->
    Out_channel.output_string oc formatted;
    Out_channel.output_char oc '\n')

let () =
  (* Ensure snapshots directory exists *)
  if not (Sys.file_exists snapshots_dir) then
    Unix.mkdir snapshots_dir 0o755;

  Printf.printf "Starting server...\n%!";

  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let proc = start_server ~sw ~env in
  Fun.protect
    ~finally:(fun () ->
      Printf.printf "Stopping server...\n%!";
      stop_server proc)
    (fun () ->
      Printf.printf "Server started, updating snapshots...\n%!";
      List.iter (fun endpoint ->
        let status, body = get ~env ~sw endpoint in
        if status = 200 then begin
          write_snapshot endpoint body;
          Printf.printf "  ✓ %s\n%!" endpoint
        end else
          Printf.printf "  ✗ %s (status %d)\n%!" endpoint status
      ) endpoints;
      Printf.printf "Done!\n%!")
