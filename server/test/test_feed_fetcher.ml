(* Tests for Feed_fetcher *)

open Connections_server
open Test_helpers

let test_ptime_to_string () =
  (* Create a known Ptime value *)
  match Ptime.of_date_time ((2024, 6, 15), ((10, 30, 45), 0)) with
  | None -> Alcotest.fail "failed to create ptime"
  | Some ptime ->
      let result = Feed_fetcher.ptime_to_string ptime in
      Alcotest.(check string) "formats correctly" "2024-06-15 10:30:45" result

let test_parse_feed_invalid () =
  let result = Feed_fetcher.parse_feed "not valid xml" in
  match result with
  | Error _ -> () (* Expected *)
  | Ok _ -> Alcotest.fail "expected parse error for invalid XML"

let test_parse_feed_empty () =
  let result = Feed_fetcher.parse_feed "" in
  match result with
  | Error _ -> () (* Expected *)
  | Ok _ -> Alcotest.fail "expected parse error for empty string"

let suite =
  [
    sync_test "ptime_to_string formats correctly" test_ptime_to_string;
    sync_test "parse_feed rejects invalid XML" test_parse_feed_invalid;
    sync_test "parse_feed rejects empty string" test_parse_feed_empty;
  ]
