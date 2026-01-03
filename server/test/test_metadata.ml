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

(* Contact metadata tests *)

let test_contact_extract_feeds () =
  let result =
    Metadata.Contact.extract ~url:"https://example.com" ~html:html_with_feeds
  in
  Alcotest.(check int) "found 3 feeds" 3 (List.length result.feeds);
  let rss_feed = List.nth result.feeds 0 in
  Alcotest.(check string)
    "RSS feed URL resolved" "https://example.com/feed.xml" rss_feed.url;
  Alcotest.(check (option string))
    "RSS feed title" (Some "RSS Feed") rss_feed.title

let test_contact_extract_microformats () =
  let result =
    Metadata.Contact.extract ~url:"https://example.com"
      ~html:html_with_microformats
  in
  Alcotest.(check (option string))
    "author name" (Some "Author Name") result.name;
  Alcotest.(check (option string))
    "author url" (Some "https://example.com/author") result.url;
  Alcotest.(check (option string))
    "author photo" (Some "https://example.com/avatar.jpg") result.photo;
  Alcotest.(check (option string))
    "author bio" (Some "Author bio here") result.bio;
  Alcotest.(check (option string))
    "author location" (Some "San Francisco, USA") result.location;
  Alcotest.(check int)
    "social profiles (email + 2 rel-me)" 3
    (List.length result.social_profiles)

let test_contact_extract_json_ld_person () =
  let result =
    Metadata.Contact.extract ~url:"https://example.com" ~html:html_with_json_ld
  in
  (* JSON-LD article author should be extracted *)
  Alcotest.(check (option string)) "author name" (Some "Jane Smith") result.name;
  Alcotest.(check (option string))
    "author url" (Some "https://example.com/jane") result.url;
  Alcotest.(check int)
    "2 social profiles from sameAs" 2
    (List.length result.social_profiles)

(* Article metadata tests *)

let test_article_extract_opengraph () =
  let result =
    Metadata.Article.extract ~url:"https://example.com"
      ~html:html_with_opengraph
  in
  Alcotest.(check (option string)) "OG title" (Some "OG Title") result.title;
  Alcotest.(check (option string))
    "OG description" (Some "OG Description") result.description;
  Alcotest.(check (option string))
    "OG image" (Some "https://example.com/image.jpg") result.image;
  Alcotest.(check (option string))
    "OG type" (Some "article") result.content_type;
  Alcotest.(check (option string))
    "published time" (Some "2024-01-15T10:00:00Z") result.published_at;
  Alcotest.(check int) "2 tags" 2 (List.length result.tags);
  Alcotest.(check (option string))
    "site name" (Some "Example Site") result.site_name;
  Alcotest.(check (option string))
    "canonical url" (Some "https://example.com/article") result.canonical_url

let test_article_extract_twitter () =
  let result =
    Metadata.Article.extract ~url:"https://example.com" ~html:html_with_twitter
  in
  Alcotest.(check (option string))
    "Twitter title" (Some "Twitter Title") result.title;
  Alcotest.(check (option string))
    "Twitter description" (Some "Twitter Description") result.description;
  Alcotest.(check (option string))
    "Twitter image" (Some "https://example.com/twitter-image.jpg") result.image;
  Alcotest.(check (option string))
    "Twitter creator as author" (Some "@johndoe") result.author_name

let test_article_extract_json_ld () =
  let result =
    Metadata.Article.extract ~url:"https://example.com" ~html:html_with_json_ld
  in
  Alcotest.(check (option string))
    "JSON-LD headline" (Some "JSON-LD Headline") result.title;
  Alcotest.(check (option string))
    "JSON-LD description" (Some "JSON-LD description") result.description;
  Alcotest.(check (option string))
    "JSON-LD published" (Some "2024-01-20T09:00:00Z") result.published_at;
  Alcotest.(check (option string))
    "JSON-LD modified" (Some "2024-01-21T14:30:00Z") result.modified_at;
  Alcotest.(check (option string))
    "JSON-LD author name" (Some "Jane Smith") result.author_name;
  Alcotest.(check (option string))
    "JSON-LD image" (Some "https://example.com/article-image.jpg") result.image

let test_article_extract_html_meta () =
  let result =
    Metadata.Article.extract ~url:"https://example.com"
      ~html:html_with_html_meta
  in
  Alcotest.(check (option string))
    "HTML title" (Some "HTML Meta Page") result.title;
  Alcotest.(check (option string))
    "HTML description" (Some "Meta description") result.description;
  Alcotest.(check (option string))
    "HTML author" (Some "Meta Author") result.author_name;
  Alcotest.(check (option string))
    "canonical URL" (Some "https://example.com/canonical") result.canonical_url

let test_article_priority () =
  (* JSON-LD should take priority over OG over Twitter over HTML *)
  let html =
    {|<!DOCTYPE html>
<html>
<head>
  <title>HTML Title</title>
  <meta name="description" content="HTML description">
  <meta property="og:title" content="OG Title">
  <meta property="og:description" content="OG description">
  <meta name="twitter:title" content="Twitter Title">
  <script type="application/ld+json">
  {
    "@type": "Article",
    "headline": "JSON-LD Title",
    "description": "JSON-LD description"
  }
  </script>
</head>
<body></body>
</html>|}
  in
  let result = Metadata.Article.extract ~url:"https://example.com" ~html in
  Alcotest.(check (option string))
    "title from JSON-LD" (Some "JSON-LD Title") result.title;
  Alcotest.(check (option string))
    "description from JSON-LD" (Some "JSON-LD description") result.description

let test_contact_relative_url_resolution () =
  let html =
    {|<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/rss+xml" href="/feed.xml">
</head>
<body>
  <div class="h-card">
    <img class="u-photo" src="avatar.jpg">
  </div>
</body>
</html>|}
  in
  let result =
    Metadata.Contact.extract ~url:"https://example.com/blog/" ~html
  in
  let feed = List.nth result.feeds 0 in
  Alcotest.(check string)
    "feed URL resolved" "https://example.com/feed.xml" feed.url;
  Alcotest.(check (option string))
    "photo resolved" (Some "https://example.com/blog/avatar.jpg") result.photo

let suite =
  [
    Alcotest.test_case "contact: extract feeds" `Quick
      test_contact_extract_feeds;
    Alcotest.test_case "contact: extract microformats" `Quick
      test_contact_extract_microformats;
    Alcotest.test_case "contact: extract JSON-LD person" `Quick
      test_contact_extract_json_ld_person;
    Alcotest.test_case "article: extract OpenGraph" `Quick
      test_article_extract_opengraph;
    Alcotest.test_case "article: extract Twitter Cards" `Quick
      test_article_extract_twitter;
    Alcotest.test_case "article: extract JSON-LD" `Quick
      test_article_extract_json_ld;
    Alcotest.test_case "article: extract HTML meta" `Quick
      test_article_extract_html_meta;
    Alcotest.test_case "article: priority ordering" `Quick test_article_priority;
    Alcotest.test_case "contact: relative URL resolution" `Quick
      test_contact_relative_url_resolution;
  ]
