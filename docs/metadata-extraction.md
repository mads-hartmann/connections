# URL Metadata Extraction

## Endpoint

```
GET /url-metadata?url=<url>
```

Returns extracted metadata from the given URL.

## Supported Sources

| Source | Data Extracted |
|--------|----------------|
| [HTML meta](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta) | title, description, author, canonical URL, favicon |
| [Open Graph](https://ogp.me/) | title, type, image, description, site name, locale, publish/modify dates |
| [Twitter Cards](https://developer.x.com/en/docs/x-for-websites/cards/overview/abouts-cards) | card type, site, creator, title, description, image |
| [JSON-LD](https://json-ld.org/) | Person (name, url, image, job title, sameAs), Article (headline, author, dates) |
| [Microformats2](https://microformats.org/wiki/microformats2) | h-card (author info), h-entry (content), rel-me (identity links) |
| [Feed discovery](https://www.rssboard.org/rss-autodiscovery) | RSS, Atom, JSON Feed via `<link rel="alternate">` |

## Merge Priority

When the same field appears in multiple sources, higher priority wins:

1. Microformats2
2. JSON-LD
3. Open Graph
4. Twitter Cards
5. HTML meta

## Response Structure

```json
{
  "merged": {
    "url": "https://example.com",
    "feeds": [{ "url": "...", "title": "...", "format": "rss|atom|json_feed" }],
    "author": { "name": "...", "url": "...", "email": "...", "photo": "...", "bio": "...", "location": "...", "social_profiles": [] },
    "content": { "title": "...", "description": "...", "published_at": "...", "modified_at": "...", "image": "...", "tags": [] },
    "site": { "name": "...", "canonical_url": "...", "favicon": "...", "locale": "..." }
  },
  "sources": {
    "html_meta": { ... },
    "opengraph": { ... },
    "twitter": { ... },
    "json_ld": { ... },
    "microformats": { ... }
  }
}
```

## Redirect Handling

Follows HTTP 301, 302, 303, 307, 308 redirects up to 10 hops.
