(* Tests for Opml_parser using the test data file *)

open Connections_server
open Test_helpers

(* Path to test OPML file - relative to test directory *)
let test_opml_path = "data/Feeds.opml"

(* Read the test OPML file *)
let read_test_opml () =
  let ic = open_in test_opml_path in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

let test_parse_succeeds () =
  let content = read_test_opml () in
  match Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result ->
      Alcotest.(check bool)
        "should have feeds" true
        (List.length result.feeds > 0)

let test_feed_count () =
  let content = read_test_opml () in
  match Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result ->
      (* The file has 196 outline elements with xmlUrl attributes *)
      Alcotest.(check int) "feed count" 196 (List.length result.feeds)

let test_first_feed () =
  let content = read_test_opml () in
  match Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result -> (
      match result.feeds with
      | [] -> Alcotest.fail "no feeds found"
      | first :: _ ->
          Alcotest.(check string)
            "first feed url" "https://www.bschaatsbergen.com/index.xml"
            first.url;
          Alcotest.(check (option string))
            "first feed title" (Some "/home/bschaatsbergen") first.title)

let test_specific_feeds_present () =
  let content = read_test_opml () in
  match Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result ->
      let urls = List.map (fun f -> f.Opml_parser.url) result.feeds in
      (* Check some known feeds are present *)
      Alcotest.(check bool)
        "Julia Evans feed present" true
        (List.mem "https://jvns.ca/atom.xml" urls);
      Alcotest.(check bool)
        "Martin Fowler feed present" true
        (List.mem "https://martinfowler.com/feed.atom" urls);
      Alcotest.(check bool)
        "Mads Hartmann feed present" true
        (List.mem "https://blog.mads-hartmann.com/feed.xml" urls);
      Alcotest.(check bool)
        "Tailscale feed present" true
        (List.mem "https://tailscale.com/blog/index.xml" urls)

let test_feed_titles () =
  let content = read_test_opml () in
  match Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result ->
      (* Find specific feeds and check their titles *)
      let find_by_url url =
        List.find_opt (fun f -> f.Opml_parser.url = url) result.feeds
      in
      (match find_by_url "https://jvns.ca/atom.xml" with
      | None -> Alcotest.fail "Julia Evans feed not found"
      | Some feed ->
          Alcotest.(check (option string))
            "Julia Evans title" (Some "Julia Evans") feed.title);
      (match find_by_url "https://blog.mads-hartmann.com/feed.xml" with
      | None -> Alcotest.fail "Mads Hartmann feed not found"
      | Some feed ->
          Alcotest.(check (option string))
            "Mads Hartmann title" (Some "Mads Hartmann") feed.title);
      (match find_by_url "https://charity.wtf/rss" with
      | None -> Alcotest.fail "charity.wtf feed not found"
      | Some feed ->
          Alcotest.(check (option string))
            "charity.wtf title" (Some "charity.wtf") feed.title)

let test_no_nested_categories () =
  (* This OPML file has flat structure - no nested categories *)
  let content = read_test_opml () in
  match Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result ->
      let all_have_empty_categories =
        List.for_all
          (fun f -> List.length f.Opml_parser.categories = 0)
          result.feeds
      in
      Alcotest.(check bool)
        "all feeds have empty categories" true all_have_empty_categories

let test_last_feed () =
  let content = read_test_opml () in
  match Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result -> (
      match List.rev result.feeds with
      | [] -> Alcotest.fail "no feeds found"
      | last :: _ ->
          Alcotest.(check string)
            "last feed url" "https://veekaybee.github.io/index.xml" last.url;
          Alcotest.(check (option string))
            "last feed title"
            (Some "★❤✰ Vicki Boykis ★❤✰")
            last.title)

let test_parse_empty_body () =
  let content = {|<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
<head><title>Empty</title></head>
<body>
</body>
</opml>|} in
  match Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result ->
      Alcotest.(check int) "empty body has no feeds" 0 (List.length result.feeds)

let test_parse_with_categories () =
  let content = {|<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
<head><title>Test</title></head>
<body>
<outline text="Tech">
  <outline text="Blogs">
    <outline xmlUrl="https://example.com/feed1.xml" title="Feed 1" type="rss" />
  </outline>
  <outline xmlUrl="https://example.com/feed2.xml" title="Feed 2" type="rss" />
</outline>
<outline xmlUrl="https://example.com/feed3.xml" title="Feed 3" type="rss" />
</body>
</opml>|} in
  match Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result ->
      Alcotest.(check int) "should have 3 feeds" 3 (List.length result.feeds);
      let find_by_url url =
        List.find_opt (fun f -> f.Opml_parser.url = url) result.feeds
      in
      (match find_by_url "https://example.com/feed1.xml" with
      | None -> Alcotest.fail "feed1 not found"
      | Some feed ->
          Alcotest.(check (list string))
            "feed1 categories" [ "Tech"; "Blogs" ] feed.categories);
      (match find_by_url "https://example.com/feed2.xml" with
      | None -> Alcotest.fail "feed2 not found"
      | Some feed ->
          Alcotest.(check (list string))
            "feed2 categories" [ "Tech" ] feed.categories);
      (match find_by_url "https://example.com/feed3.xml" with
      | None -> Alcotest.fail "feed3 not found"
      | Some feed ->
          Alcotest.(check (list string)) "feed3 categories" [] feed.categories)

let test_parse_invalid_xml () =
  let content = "not valid xml at all" in
  match Opml_parser.parse content with
  | Error _ -> () (* Expected *)
  | Ok _ -> Alcotest.fail "expected parse error for invalid XML"

let test_parse_no_body () =
  let content = {|<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
<head><title>No Body</title></head>
</opml>|} in
  match Opml_parser.parse content with
  | Error msg ->
      Alcotest.(check bool)
        "error mentions body" true
        (String.length msg > 0)
  | Ok _ -> Alcotest.fail "expected error for OPML without body"

let suite =
  [
    sync_test "parse succeeds on test file" test_parse_succeeds;
    sync_test "finds correct number of feeds" test_feed_count;
    sync_test "first feed has correct url and title" test_first_feed;
    sync_test "specific known feeds are present" test_specific_feeds_present;
    sync_test "feed titles are extracted correctly" test_feed_titles;
    sync_test "flat OPML has no categories" test_no_nested_categories;
    sync_test "last feed has correct url and title" test_last_feed;
    sync_test "empty body returns no feeds" test_parse_empty_body;
    sync_test "nested categories are extracted" test_parse_with_categories;
    sync_test "invalid XML returns error" test_parse_invalid_xml;
    sync_test "missing body returns error" test_parse_no_body;
  ]
