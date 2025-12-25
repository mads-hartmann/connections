(* End-to-end tests that start the server and test API endpoints *)

let server_port = 18080
let base_url = Printf.sprintf "http://localhost:%d" server_port

(* Server process management *)
let server_process : int option ref = ref None

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

let find_workspace_root () =
  (* Walk up from cwd looking for dune-project *)
  let rec find dir =
    let dune_project = Filename.concat dir "dune-project" in
    if Sys.file_exists dune_project then Some dir
    else
      let parent = Filename.dirname dir in
      if parent = dir then None else find parent
  in
  find (Sys.getcwd ())

let workspace_root =
  match find_workspace_root () with
  | Some root -> root
  | None -> failwith "Could not find workspace root (dune-project)"

let test_db_path = Filename.concat workspace_root "server/test/data/test.db"
let snapshots_dir = Filename.concat workspace_root "server/test/data/snapshots"

let start_server ~sw ~env =
  let executable = Filename.concat workspace_root "_build/default/server/bin/main.exe" in
  if not (Sys.file_exists executable) then
    failwith (Printf.sprintf "Server executable not found: %s" executable);
  let args = [
    executable;
    "--db"; test_db_path;
    "--port"; string_of_int server_port;
    "--no-scheduler"
  ] in
  let mgr = Eio.Stdenv.process_mgr env in
  let proc = Eio.Process.spawn ~sw mgr args in
  let pid = Eio.Process.pid proc in
  server_process := Some pid;
  wait_for_server ~env ~timeout_seconds:10.0;
  proc

let stop_server proc =
  Eio.Process.signal proc Sys.sigterm;
  ignore (Eio.Process.await proc);
  server_process := None

(* HTTP client helpers *)
let make_request ~env ~sw ~meth ~path =
  let uri = Uri.of_string (base_url ^ path) in
  let client = Piaf.Client.create ~sw env uri in
  match client with
  | Error err ->
      failwith (Format.asprintf "Failed to create client: %a" Piaf.Error.pp_hum err)
  | Ok client ->
      let response = Piaf.Client.request client ~meth (Uri.path_and_query uri) in
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

let get ~env ~sw path = make_request ~env ~sw ~meth:`GET ~path

(* Snapshot helpers *)
let snapshot_path endpoint =
  (* Convert endpoint path to filename: /persons -> persons.json, /persons/1 -> persons_1.json *)
  let name =
    endpoint
    |> String.split_on_char '/'
    |> List.filter (fun s -> s <> "")
    |> String.concat "_"
  in
  Filename.concat snapshots_dir (name ^ ".json")

let read_snapshot endpoint =
  let path = snapshot_path endpoint in
  if Sys.file_exists path then
    Some (In_channel.with_open_text path In_channel.input_all)
  else
    None

let normalize_json str =
  (* Parse and re-serialize to normalize formatting *)
  try
    let json = Yojson.Safe.from_string str in
    Yojson.Safe.pretty_to_string json
  with _ -> str

(* Test case builder *)
let test_endpoint endpoint () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let proc = start_server ~sw ~env in
  Fun.protect
    ~finally:(fun () -> stop_server proc)
    (fun () ->
      let status, body = get ~env ~sw endpoint in
      Alcotest.(check int) "status is 200" 200 status;
      match read_snapshot endpoint with
      | None ->
          Alcotest.fail
            (Printf.sprintf "Snapshot not found for %s. Run update_snapshots to create it." endpoint)
      | Some expected ->
          let actual_normalized = normalize_json body in
          let expected_normalized = normalize_json expected in
          Alcotest.(check string) "response matches snapshot" expected_normalized actual_normalized)

(* Define test endpoints *)
let endpoints = [
  "/persons";
  "/persons/1";
  "/feeds";
  "/feeds/1";
  "/articles";
  "/articles/1";
  "/categories";
  "/categories/1";
]

let suite =
  List.map
    (fun endpoint ->
      let name = Printf.sprintf "GET %s" endpoint in
      Alcotest.test_case name `Slow (test_endpoint endpoint))
    endpoints
