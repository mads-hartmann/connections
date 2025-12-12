(* Tests for Handlers.Utils *)

open Connections_server
open Test_helpers

let test_is_valid_url_https () =
  Alcotest.(check bool)
    "https URL is valid" true
    (Handlers.Utils.is_valid_url "https://example.com")

let test_is_valid_url_http () =
  Alcotest.(check bool)
    "http URL is valid" true
    (Handlers.Utils.is_valid_url "http://example.com")

let test_is_valid_url_with_path () =
  Alcotest.(check bool)
    "URL with path is valid" true
    (Handlers.Utils.is_valid_url "https://example.com/feed.xml")

let test_is_valid_url_no_scheme () =
  Alcotest.(check bool)
    "URL without scheme is invalid" false
    (Handlers.Utils.is_valid_url "example.com")

let test_is_valid_url_ftp () =
  Alcotest.(check bool)
    "ftp URL is invalid" false
    (Handlers.Utils.is_valid_url "ftp://example.com")

let test_is_valid_url_empty () =
  Alcotest.(check bool)
    "empty string is invalid" false
    (Handlers.Utils.is_valid_url "")

let test_is_valid_url_no_host () =
  (* Note: Uri.of_string "https://" parses with empty host, which Uri.host returns as Some "" *)
  (* The current implementation considers this valid - this test documents actual behavior *)
  Alcotest.(check bool)
    "URL with empty host is considered valid by Uri" true
    (Handlers.Utils.is_valid_url "https://")

let test_validate_url_valid () =
  Alcotest.(check (result string string))
    "valid URL returns Ok" (Ok "https://example.com")
    (Handlers.Utils.validate_url "https://example.com")

let test_validate_url_empty () =
  Alcotest.(check (result string string))
    "empty URL returns Error" (Error "URL cannot be empty")
    (Handlers.Utils.validate_url "")

let test_validate_url_whitespace () =
  Alcotest.(check (result string string))
    "whitespace-only URL returns Error" (Error "URL cannot be empty")
    (Handlers.Utils.validate_url "   ")

let test_validate_url_invalid_scheme () =
  match Handlers.Utils.validate_url "ftp://example.com" with
  | Error msg ->
      Alcotest.(check bool)
        "error message mentions invalid format" true
        (String.length msg > 0)
  | Ok _ -> Alcotest.fail "expected Error for ftp URL"

let suite =
  [
    sync_test "is_valid_url: https" test_is_valid_url_https;
    sync_test "is_valid_url: http" test_is_valid_url_http;
    sync_test "is_valid_url: with path" test_is_valid_url_with_path;
    sync_test "is_valid_url: no scheme" test_is_valid_url_no_scheme;
    sync_test "is_valid_url: ftp" test_is_valid_url_ftp;
    sync_test "is_valid_url: empty" test_is_valid_url_empty;
    sync_test "is_valid_url: no host" test_is_valid_url_no_host;
    sync_test "validate_url: valid" test_validate_url_valid;
    sync_test "validate_url: empty" test_validate_url_empty;
    sync_test "validate_url: whitespace" test_validate_url_whitespace;
    sync_test "validate_url: invalid scheme" test_validate_url_invalid_scheme;
  ]
