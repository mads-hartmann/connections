(* Tests for utility functions *)

open Connections_server

let test_validate_url_valid_http () =
  let result = Handlers.Handler_utils.validate_url "http://example.com" in
  Alcotest.(check bool) "http URL is valid" true (Result.is_ok result)

let test_validate_url_valid_https () =
  let result = Handlers.Handler_utils.validate_url "https://example.com/path" in
  Alcotest.(check bool) "https URL is valid" true (Result.is_ok result)

let test_validate_url_empty () =
  let result = Handlers.Handler_utils.validate_url "" in
  Alcotest.(check bool) "empty URL is invalid" true (Result.is_error result)

let test_validate_url_no_scheme () =
  let result = Handlers.Handler_utils.validate_url "example.com" in
  Alcotest.(check bool)
    "URL without scheme is invalid" true (Result.is_error result)

let test_validate_url_ftp () =
  let result = Handlers.Handler_utils.validate_url "ftp://example.com" in
  Alcotest.(check bool) "ftp URL is invalid" true (Result.is_error result)

let suite =
  [
    Alcotest.test_case "validate_url accepts http" `Quick
      test_validate_url_valid_http;
    Alcotest.test_case "validate_url accepts https" `Quick
      test_validate_url_valid_https;
    Alcotest.test_case "validate_url rejects empty" `Quick
      test_validate_url_empty;
    Alcotest.test_case "validate_url rejects no scheme" `Quick
      test_validate_url_no_scheme;
    Alcotest.test_case "validate_url rejects ftp" `Quick test_validate_url_ftp;
  ]
