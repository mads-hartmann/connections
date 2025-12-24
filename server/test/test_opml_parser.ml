(* Tests for Opml.Opml_parser using the test data file *)

open Connections_server

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
  match Opml.Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result ->
      Alcotest.(check bool)
        "should have feeds" true
        (List.length result.feeds > 0)

let test_feed_count () =
  let content = read_test_opml () in
  match Opml.Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result ->
      (* The file has 196 outline elements with xmlUrl attributes *)
      Alcotest.(check int) "feed count" 196 (List.length result.feeds)

let test_first_feed () =
  let content = read_test_opml () in
  match Opml.Opml_parser.parse content with
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
  match Opml.Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result ->
      let urls = List.map (fun f -> f.Opml.Opml_parser.url) result.feeds in
      (* Check some known feeds are present *)
      Alcotest.(check bool)
        "Julia Evans feed present" true
        (List.mem "https://jvns.ca/atom.xml" urls);
      Alcotest.(check bool)
        "Martin Fowler feed present" true
        (List.mem "https://martinfowler.com/feed.atom" urls)

let test_parse_empty_body () =
  let content =
    {|<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
<head><title>Empty</title></head>
<body>
</body>
</opml>|}
  in
  match Opml.Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result ->
      Alcotest.(check int)
        "empty body has no feeds" 0 (List.length result.feeds)

let test_parse_with_categories () =
  let content =
    {|<?xml version="1.0" encoding="UTF-8"?>
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
</opml>|}
  in
  match Opml.Opml_parser.parse content with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok result -> (
      Alcotest.(check int) "should have 3 feeds" 3 (List.length result.feeds);
      let find_by_url url =
        List.find_opt (fun f -> f.Opml.Opml_parser.url = url) result.feeds
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
      match find_by_url "https://example.com/feed3.xml" with
      | None -> Alcotest.fail "feed3 not found"
      | Some feed ->
          Alcotest.(check (list string)) "feed3 categories" [] feed.categories)

let test_parse_invalid_xml () =
  let content = "not valid xml at all" in
  match Opml.Opml_parser.parse content with
  | Error _ -> () (* Expected *)
  | Ok _ -> Alcotest.fail "expected parse error for invalid XML"

let suite =
  [
    Alcotest.test_case "parse succeeds on test file" `Quick test_parse_succeeds;
    Alcotest.test_case "finds correct number of feeds" `Quick test_feed_count;
    Alcotest.test_case "first feed has correct url and title" `Quick
      test_first_feed;
    Alcotest.test_case "specific known feeds are present" `Quick
      test_specific_feeds_present;
    Alcotest.test_case "empty body returns no feeds" `Quick
      test_parse_empty_body;
    Alcotest.test_case "nested categories are extracted" `Quick
      test_parse_with_categories;
    Alcotest.test_case "invalid XML returns error" `Quick test_parse_invalid_xml;
  ]
