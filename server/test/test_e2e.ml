(* End-to-end tests that start the server and test API endpoints *)

let server_port = 18080

let test_endpoint endpoint () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let proc = E2e_helpers.start_server ~sw ~env ~port:server_port in
  Fun.protect
    ~finally:(fun () -> E2e_helpers.stop_server proc)
    (fun () ->
      let status, body =
        E2e_helpers.http_get ~env ~sw ~port:server_port endpoint
      in
      Alcotest.(check int) "status is 200" 200 status;
      match E2e_helpers.read_snapshot endpoint with
      | None ->
          Alcotest.fail
            (Printf.sprintf
               "Snapshot not found for %s. Run update_snapshots to create it."
               endpoint)
      | Some expected ->
          let actual_normalized = E2e_helpers.normalize_json body in
          let expected_normalized = E2e_helpers.normalize_json expected in
          Alcotest.(check string)
            "response matches snapshot" expected_normalized actual_normalized)

let suite =
  List.map
    (fun endpoint ->
      let name = Printf.sprintf "GET %s" endpoint in
      Alcotest.test_case name `Slow (test_endpoint endpoint))
    E2e_helpers.endpoints
