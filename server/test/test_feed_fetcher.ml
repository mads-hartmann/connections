(* Tests for Feed Fetcher - parsing only, no network *)

open Connections_server

let test_parse_rss2_feed () =
  let rss_content =
    {|<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <link>https://example.com</link>
    <description>A test feed</description>
    <item>
      <title>Test Article</title>
      <link>https://example.com/article1</link>
      <description>Article content</description>
    </item>
  </channel>
</rss>|}
  in
  let result = Feed_fetcher.parse_feed rss_content in
  match result with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok (Feed_fetcher.Rss2 channel) ->
      Alcotest.(check string) "title matches" "Test Feed" channel.title;
      Alcotest.(check int) "has 1 item" 1 (List.length channel.items)
  | Ok (Feed_fetcher.Atom _) -> Alcotest.fail "expected RSS2, got Atom"

let test_parse_atom_feed () =
  let atom_content =
    {|<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Test Atom Feed</title>
  <id>urn:uuid:test-feed</id>
  <updated>2024-01-01T12:00:00Z</updated>
  <author><name>Test Author</name></author>
  <entry>
    <title>Test Entry</title>
    <id>urn:uuid:test-entry</id>
    <updated>2024-01-01T12:00:00Z</updated>
    <author><name>Entry Author</name></author>
    <link href="https://example.com/entry1"/>
  </entry>
</feed>|}
  in
  let result = Feed_fetcher.parse_feed atom_content in
  match result with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok (Feed_fetcher.Atom feed) ->
      Alcotest.(check int) "has 1 entry" 1 (List.length feed.entries)
  | Ok (Feed_fetcher.Rss2 _) -> Alcotest.fail "expected Atom, got RSS2"

let test_extract_metadata_rss2 () =
  let rss_content =
    {|<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>My Blog</title>
    <link>https://example.com</link>
    <description>A blog</description>
  </channel>
</rss>|}
  in
  let result = Feed_fetcher.parse_feed rss_content in
  match result with
  | Error msg -> Alcotest.fail ("parse failed: " ^ msg)
  | Ok parsed ->
      let metadata = Feed_fetcher.extract_metadata parsed in
      Alcotest.(check (option string))
        "title extracted" (Some "My Blog") metadata.title

let suite =
  [
    Alcotest.test_case "parse RSS2 feed" `Quick test_parse_rss2_feed;
    Alcotest.test_case "parse Atom feed" `Quick test_parse_atom_feed;
    Alcotest.test_case "extract metadata from RSS2" `Quick
      test_extract_metadata_rss2;
  ]
