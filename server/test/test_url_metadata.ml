(* Tests for URL Metadata extraction - parsing only, no network *)

open Connections_server

(* Test HTML fixtures *)

let html_with_feeds =
  {|<!DOCTYPE html>
<html>
<head>
  <title>Test Page</title>
  <link rel="alternate" type="application/rss+xml" title="RSS Feed" href="/feed.xml">
  <link rel="alternate" type="application/atom+xml" title="Atom Feed" href="https://example.com/atom.xml">
  <link rel="alternate" type="application/feed+json" title="JSON Feed" href="/feed.json">
</head>
<body></body>
</html>|}

let html_with_opengraph =
  {|<!DOCTYPE html>
<html>
<head>
  <title>Page Title</title>
  <meta property="og:title" content="OG Title">
  <meta property="og:type" content="article">
  <meta property="og:url" content="https://example.com/article">
  <meta property="og:image" content="https://example.com/image.jpg">
  <meta property="og:description" content="OG Description">
  <meta property="og:site_name" content="Example Site">
  <meta property="og:locale" content="en_US">
  <meta property="article:author" content="John Doe">
  <meta property="article:published_time" content="2024-01-15T10:00:00Z">
  <meta property="article:tag" content="tech">
  <meta property="article:tag" content="web">
</head>
<body></body>
</html>|}

let html_with_twitter =
  {|<!DOCTYPE html>
<html>
<head>
  <title>Page Title</title>
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:site" content="@example">
  <meta name="twitter:creator" content="@johndoe">
  <meta name="twitter:title" content="Twitter Title">
  <meta name="twitter:description" content="Twitter Description">
  <meta name="twitter:image" content="https://example.com/twitter-image.jpg">
</head>
<body></body>
</html>|}

let html_with_json_ld =
  {|<!DOCTYPE html>
<html>
<head>
  <title>Article Page</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Article",
    "headline": "JSON-LD Headline",
    "author": {
      "@type": "Person",
      "name": "Jane Smith",
      "url": "https://example.com/jane",
      "sameAs": ["https://twitter.com/jane", "https://github.com/jane"]
    },
    "datePublished": "2024-01-20T09:00:00Z",
    "dateModified": "2024-01-21T14:30:00Z",
    "description": "JSON-LD description",
    "image": "https://example.com/article-image.jpg"
  }
  </script>
</head>
<body></body>
</html>|}

let html_with_microformats =
  {|<!DOCTYPE html>
<html>
<head>
  <title>Blog Post</title>
</head>
<body>
  <article class="h-entry">
    <h1 class="p-name">Microformat Entry Title</h1>
    <p class="p-summary">Entry summary text</p>
    <time class="dt-published" datetime="2024-02-01T08:00:00Z">Feb 1, 2024</time>
    <a class="p-category" href="/tags/ocaml">ocaml</a>
    <a class="p-category" href="/tags/web">web</a>
    <div class="p-author h-card">
      <img class="u-photo" src="/avatar.jpg">
      <a class="p-name u-url" href="https://example.com/author">Author Name</a>
      <a class="u-email" href="mailto:author@example.com">author@example.com</a>
      <p class="p-note">Author bio here</p>
      <span class="p-locality">San Francisco</span>,
      <span class="p-country-name">USA</span>
    </div>
  </article>
  <a rel="me" href="https://mastodon.social/@author">Mastodon</a>
  <a rel="me" href="https://github.com/author">GitHub</a>
</body>
</html>|}

let html_with_html_meta =
  {|<!DOCTYPE html>
<html>
<head>
  <title>HTML Meta Page</title>
  <meta name="description" content="Meta description">
  <meta name="author" content="Meta Author">
  <link rel="canonical" href="https://example.com/canonical">
  <link rel="icon" href="/favicon.ico">
  <link rel="webmention" href="https://example.com/webmention">
</head>
<body></body>
</html>|}

let html_combined =
  {|<!DOCTYPE html>
<html>
<head>
  <title>Combined Page</title>
  <meta name="description" content="HTML description">
  <meta property="og:title" content="OG Title">
  <meta property="og:description" content="OG description">
  <meta name="twitter:title" content="Twitter Title">
  <link rel="alternate" type="application/rss+xml" href="/feed.xml">
  <script type="application/ld+json">
  {
    "@type": "Article",
    "headline": "JSON-LD Title",
    "author": {"@type": "Person", "name": "JSON-LD Author"}
  }
  </script>
</head>
<body>
  <article class="h-entry">
    <h1 class="p-name">Microformat Title</h1>
    <div class="p-author h-card">
      <span class="p-name">Microformat Author</span>
    </div>
  </article>
</body>
</html>|}

(* Test cases *)

let test_extract_feeds () =
  let result =
    Url_metadata.extract ~url:"https://example.com" ~html:html_with_feeds
  in
  Alcotest.(check int) "found 3 feeds" 3 (List.length result.feeds);
  let rss_feed = List.nth result.feeds 0 in
  Alcotest.(check string)
    "RSS feed URL resolved" "https://example.com/feed.xml" rss_feed.url;
  Alcotest.(check (option string))
    "RSS feed title" (Some "RSS Feed") rss_feed.title

let test_extract_opengraph () =
  let result =
    Url_metadata.extract ~url:"https://example.com" ~html:html_with_opengraph
  in
  Alcotest.(check (option string))
    "OG title" (Some "OG Title") result.content.title;
  Alcotest.(check (option string))
    "OG description" (Some "OG Description") result.content.description;
  Alcotest.(check (option string))
    "OG image" (Some "https://example.com/image.jpg") result.content.image;
  Alcotest.(check (option string))
    "OG type" (Some "article") result.content.content_type;
  Alcotest.(check (option string))
    "published time" (Some "2024-01-15T10:00:00Z") result.content.published_at;
  Alcotest.(check int) "2 tags" 2 (List.length result.content.tags);
  Alcotest.(check (option string))
    "site name" (Some "Example Site") result.site.name;
  Alcotest.(check (option string)) "locale" (Some "en_US") result.site.locale

let test_extract_twitter () =
  let result =
    Url_metadata.extract ~url:"https://example.com" ~html:html_with_twitter
  in
  Alcotest.(check (option string))
    "Twitter title" (Some "Twitter Title") result.content.title;
  Alcotest.(check (option string))
    "Twitter description" (Some "Twitter Description")
    result.content.description;
  Alcotest.(check (option string))
    "Twitter image" (Some "https://example.com/twitter-image.jpg")
    result.content.image

let test_extract_json_ld () =
  let result =
    Url_metadata.extract ~url:"https://example.com" ~html:html_with_json_ld
  in
  Alcotest.(check (option string))
    "JSON-LD headline" (Some "JSON-LD Headline") result.content.title;
  Alcotest.(check (option string))
    "JSON-LD description" (Some "JSON-LD description")
    result.content.description;
  Alcotest.(check (option string))
    "JSON-LD published" (Some "2024-01-20T09:00:00Z")
    result.content.published_at;
  Alcotest.(check (option string))
    "JSON-LD modified" (Some "2024-01-21T14:30:00Z") result.content.modified_at;
  Alcotest.(check int) "1 raw JSON-LD block" 1 (List.length result.raw_json_ld);
  (* Check author *)
  match result.author with
  | None -> Alcotest.fail "expected author"
  | Some author ->
      Alcotest.(check (option string))
        "author name" (Some "Jane Smith") author.name;
      Alcotest.(check (option string))
        "author url" (Some "https://example.com/jane") author.url;
      Alcotest.(check int)
        "2 social profiles" 2
        (List.length author.social_profiles)

let test_extract_microformats () =
  let result =
    Url_metadata.extract ~url:"https://example.com" ~html:html_with_microformats
  in
  Alcotest.(check (option string))
    "h-entry name" (Some "Microformat Entry Title") result.content.title;
  Alcotest.(check (option string))
    "h-entry summary" (Some "Entry summary text") result.content.description;
  Alcotest.(check (option string))
    "h-entry published" (Some "2024-02-01T08:00:00Z")
    result.content.published_at;
  Alcotest.(check int) "2 categories" 2 (List.length result.content.tags);
  (* Check author from h-card *)
  match result.author with
  | None -> Alcotest.fail "expected author"
  | Some author ->
      Alcotest.(check (option string))
        "author name" (Some "Author Name") author.name;
      Alcotest.(check (option string))
        "author url" (Some "https://example.com/author") author.url;
      Alcotest.(check (option string))
        "author photo" (Some "https://example.com/avatar.jpg") author.photo;
      Alcotest.(check (option string))
        "author bio" (Some "Author bio here") author.bio;
      Alcotest.(check (option string))
        "author location" (Some "San Francisco, USA") author.location;
      Alcotest.(check int)
        "2 rel-me links" 2
        (List.length author.social_profiles)

let test_extract_html_meta () =
  let result =
    Url_metadata.extract ~url:"https://example.com" ~html:html_with_html_meta
  in
  Alcotest.(check (option string))
    "HTML title" (Some "HTML Meta Page") result.content.title;
  Alcotest.(check (option string))
    "HTML description" (Some "Meta description") result.content.description;
  Alcotest.(check (option string))
    "canonical URL" (Some "https://example.com/canonical")
    result.site.canonical_url;
  Alcotest.(check (option string))
    "favicon" (Some "https://example.com/favicon.ico") result.site.favicon;
  Alcotest.(check (option string))
    "webmention" (Some "https://example.com/webmention")
    result.site.webmention_endpoint

let test_merge_priority () =
  (* Microformats should take priority over JSON-LD over OG over Twitter over HTML *)
  let result =
    Url_metadata.extract ~url:"https://example.com" ~html:html_combined
  in
  Alcotest.(check (option string))
    "title from microformats" (Some "Microformat Title") result.content.title;
  match result.author with
  | None -> Alcotest.fail "expected author"
  | Some author ->
      Alcotest.(check (option string))
        "author from microformats" (Some "Microformat Author") author.name

let test_relative_url_resolution () =
  let html =
    {|<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/rss+xml" href="/feed.xml">
  <link rel="icon" href="favicon.ico">
</head>
<body></body>
</html>|}
  in
  let result = Url_metadata.extract ~url:"https://example.com/blog/" ~html in
  let feed = List.nth result.feeds 0 in
  Alcotest.(check string)
    "feed URL resolved" "https://example.com/feed.xml" feed.url;
  Alcotest.(check (option string))
    "favicon resolved" (Some "https://example.com/blog/favicon.ico")
    result.site.favicon

let suite =
  [
    Alcotest.test_case "extract feeds" `Quick test_extract_feeds;
    Alcotest.test_case "extract OpenGraph" `Quick test_extract_opengraph;
    Alcotest.test_case "extract Twitter Cards" `Quick test_extract_twitter;
    Alcotest.test_case "extract JSON-LD" `Quick test_extract_json_ld;
    Alcotest.test_case "extract Microformats" `Quick test_extract_microformats;
    Alcotest.test_case "extract HTML meta" `Quick test_extract_html_meta;
    Alcotest.test_case "merge priority" `Quick test_merge_priority;
    Alcotest.test_case "relative URL resolution" `Quick
      test_relative_url_resolution;
  ]
