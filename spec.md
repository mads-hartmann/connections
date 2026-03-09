# Spec: Standalone macOS App (No Backend Dependency)

## Problem Statement

The macOS app (`clients/macos`) currently acts as a thin client to the OCaml backend server. Every operation — CRUD, feed sync, metadata extraction, OPML import — goes through HTTP API calls to the backend. This requires the backend to be running and reachable, making the app unusable offline and adding deployment complexity.

The goal is to make the macOS app fully standalone: all data stored locally with iCloud sync across devices, all business logic ported to Swift, and no dependency on the OCaml backend.

## Requirements

### R1: Local Storage with Cross-Device Sync
- Use **SwiftData** with **CloudKit** for persistence and iCloud sync.
- Port the SQLite schema (7 tables + 3 junction tables) to SwiftData `@Model` classes.
- No pagination — all queries return full result sets since data is local.

### R2: RSS/Atom Feed Parsing in Swift
- Use **FeedKit** (SPM package) to replace the OCaml Syndic-based parser.
- Port feed item extraction logic: title, URL, content, author, published date, image URL, categories/tags.
- Support both RSS 2.0 and Atom feeds.

### R3: OPML Import
- Port the OCaml OPML parser to Swift using Foundation `XMLParser`.
- Keep the two-step flow: parse → preview → confirm.
- Group feeds by author (fetching feed metadata via FeedKit) with tag extraction from OPML folder hierarchy.

### R4: Feed Sync via Background Tasks
- Use `BGAppRefreshTask` for periodic feed sync when the app is not in the foreground.
- Also sync on an in-app timer while the app is running (matching the backend's 1-hour interval).
- On sync: fetch each feed, parse entries, upsert URIs, associate tags.

### R5: URL Metadata via LinkPresentation
- Use Apple's `LPMetadataProvider` to fetch URL metadata (title, description, image, site name).
- Replace the backend's OG/JSON-LD/Microformats/Twitter card extractors.
- Background-fetch metadata for URIs that don't have it yet.

### R6: HTML Content Rendering via WKWebView
- Replace the backend's HTML-to-Markdown conversion with a `WKWebView` for rendering URI content.
- Fetch the HTML directly and display it in a web view within the detail pane.

### R7: Contact Metadata Discovery
- Port the contact metadata extraction to Swift:
  - Feed discovery from `<link rel="alternate">` tags in HTML.
  - Social profile URL classification (GitHub, X, Bluesky, LinkedIn, Mastodon, YouTube, Email, Website, Other).
- Fetch HTML with `URLSession`, parse with a Swift HTML parser (SwiftSoup SPM package) for link extraction.

### R8: Remove Backend Dependencies
- Delete `APIClient.swift` and all HTTP-based service files.
- Remove the Settings view (server URL configuration).
- Remove all pagination-related model types (`ConnectionsResponse`, `FeedsResponse`, `UrisResponse`, `TagsResponse`) and pagination state from views.

## Acceptance Criteria

1. The app launches and functions with no backend server running.
2. Connections, feeds, tags, URIs, and metadata can be created, read, updated, and deleted — all persisted locally.
3. Data syncs across devices via iCloud (when signed in).
4. RSS/Atom feeds are parsed and new entries are imported as URIs.
5. OPML files can be imported with the existing preview/confirm UX.
6. URL metadata (title, image, description) is fetched for new URIs.
7. Feed sync runs periodically in the background.
8. URI content is viewable in-app via WKWebView.
9. No pagination in any list view — all items load at once.
10. No references to `APIClient`, backend URLs, or HTTP service calls remain.

## Implementation Approach

### Phase 1: SwiftData Models & Persistence Layer

**Step 1: Add SPM dependencies**
- Add `FeedKit` and `SwiftSoup` to `Package.swift`.

**Step 2: Define SwiftData models**

Port the SQLite schema to `@Model` classes. The schema has these entities:

| SwiftData Model | Source Table(s) | Key Fields |
|---|---|---|
| `CDConnection` | `connections` + `connection_tags` + `connection_metadata` | id, name, photo, note, tags (relationship), metadata (relationship), feeds (relationship), uris (relationship) |
| `CDTag` | `tags` + junction tables | id, name, connections (relationship), feeds (relationship), uris (relationship) |
| `CDFeed` | `rss_feeds` + `feed_tags` | id, connection (relationship), url, title, createdAt, lastFetchedAt, tags (relationship), uris (relationship) |
| `CDUri` | `uris` + `uri_tags` | id, feed (relationship), connection (relationship), kind, title, url, publishedAt, content, author, imageUrl, createdAt, readAt, readLaterAt, tags (relationship), ogTitle, ogDescription, ogImage, ogSiteName, ogFetchedAt, ogFetchError, vote, votedAt, note |
| `CDConnectionMetadata` | `connection_metadata` | id, connection (relationship), fieldTypeId, fieldTypeName, value |

Notes:
- Use `@Relationship` with appropriate delete rules (cascade for feeds/metadata, nullify for connection on URIs).
- `MetadataFieldType` and `UriKind` remain as Swift enums (no separate model needed).
- Junction tables (`connection_tags`, `feed_tags`, `uri_tags`) become many-to-many `@Relationship` properties.
- Prefix model names with `CD` to avoid collision with existing view-layer structs during migration, then rename once migration is complete.

**Step 3: Create a persistence service layer**

Replace the HTTP-based service files with local SwiftData equivalents:

| New Service | Replaces | Responsibilities |
|---|---|---|
| `ConnectionStore` | `ConnectionService` + `APIClient` | CRUD connections, query with search, counts |
| `FeedStore` | `FeedService` + `APIClient` | CRUD feeds, list by connection |
| `UriStore` | `UriService` + `APIClient` | CRUD URIs, filtering (unread/readLater/upvoted/downvoted/orphan/tag), mark read, vote, mark all read |
| `TagStore` | `TagService` + `APIClient` | CRUD tags, add/remove from connections/feeds/URIs |
| `MetadataStore` | `MetadataService` + `APIClient` | CRUD connection metadata |

Each store takes a `ModelContext` and provides synchronous or async methods. No pagination parameters — return `[Model]` directly.

**Step 4: Configure SwiftData container with CloudKit**

In `ConnectionsApp.swift`:
- Create `ModelContainer` with CloudKit configuration.
- Set up the schema with all `@Model` types.
- Inject via `.modelContainer()` modifier.

### Phase 2: Port Business Logic to Swift

**Step 5: RSS/Atom feed parsing with FeedKit**

Create `FeedParser.swift`:
- Parse feed content string → extract metadata (author, title).
- Extract feed items → `ParsedFeedItem` structs (title, url, content, author, publishedAt, imageUrl, categories).
- Handle both RSS and Atom via FeedKit's unified API.

**Step 6: OPML parser in Swift**

Create `OpmlParser.swift`:
- Use `XMLParser` (Foundation) to parse OPML.
- Extract `OpmlFeedEntry` structs: url, title, tags (from folder hierarchy).
- Port the recursive outline parsing logic from the OCaml implementation.

**Step 7: Feed sync engine**

Create `FeedSyncService.swift`:
- `syncAllFeeds()`: fetch all feeds, parse each, upsert URIs, associate tags.
- `syncFeed(_ feed: CDFeed)`: fetch single feed, parse, upsert.
- Upsert logic: match by (feedId, url) for feed URIs, by url for manual URIs.
- Tag association: create-or-get tags from feed item categories, apply feed-level tags.
- Update `lastFetchedAt` on feed after sync.

**Step 8: URL metadata fetching with LinkPresentation**

Create `UrlMetadataService.swift`:
- Use `LPMetadataProvider` to fetch metadata for a URL.
- Map to ogTitle, ogDescription, ogImage, ogSiteName fields on `CDUri`.
- `fetchMetadataForPending()`: batch-process URIs where `ogFetchedAt` is nil.

**Step 9: Contact metadata discovery**

Create `ContactDiscoveryService.swift`:
- Fetch HTML from a URL via `URLSession`.
- Parse with SwiftSoup to extract `<link rel="alternate">` feed links.
- Classify social profile URLs by domain (port `classify_profiles` logic).
- Return discovered name, photo, feeds, social profiles.

**Step 10: HTML content rendering**

Create `WebContentView.swift` (SwiftUI wrapper around `WKWebView`):
- Fetch HTML from URI's URL.
- Display in WKWebView with reader-friendly styling.
- Replace the current markdown-based `UriDetailView` content pane.

### Phase 3: Update Views

**Step 11: Remove pagination from all views**

Update every view that currently uses page/hasMore/loadMore:
- `SidebarView`: load all connections at once, filter locally.
- `UriListView`: load all URIs matching filter, no "Load More" button.
- `ConnectionDetailPaneView`: load all URIs for connection.
- `FeedListView` / `FeedUriListView`: load all feeds/URIs.
- `TagListView` / `TagUriListView`: load all tags/URIs.

Replace `ConnectionsResponse`, `FeedsResponse`, `UrisResponse`, `TagsResponse` with direct `[Model]` arrays.

**Step 12: Rewire views to use SwiftData stores**

- Replace all `ConnectionService.xxx()` calls with `ConnectionStore` methods.
- Replace all `FeedService.xxx()` calls with `FeedStore` methods.
- Replace all `UriService.xxx()` calls with `UriStore` methods.
- Replace all `TagService.xxx()` calls with `TagStore` methods.
- Replace all `MetadataService.xxx()` calls with local `ContactDiscoveryService`.
- Replace all `ImportService.xxx()` calls with local `OpmlParser` + `FeedParser` + store writes.

Use `@Query` macros where appropriate for reactive SwiftData queries in views.

**Step 13: Update OPML import flow**

- Parse OPML locally (no server call).
- Fetch feed metadata locally via FeedKit (with concurrency limiting).
- Preview/confirm flow stays the same UX, but writes directly to SwiftData.

**Step 14: Update connection creation flow**

- `ConnectionCreateView`: fetch HTML locally, parse with SwiftSoup for feed/profile discovery.
- `ConnectionRefreshMetadataView`: same local fetch + parse.

**Step 15: Update URI creation flow**

- `CreateUriView`: use `LPMetadataProvider` instead of `MetadataService.fetchUriMetadata`.
- `findByHost` query runs against local SwiftData.

**Step 16: Update URI detail view**

- Replace markdown content pane with `WebContentView` (WKWebView).
- Keep the metadata sidebar as-is, reading from SwiftData model.

### Phase 4: Background Sync & Cleanup

**Step 17: Set up BGAppRefreshTask**

- Register `BGAppRefreshTask` in `Info.plist` and app delegate.
- Schedule periodic feed sync (1 hour interval).
- On trigger: run `FeedSyncService.syncAllFeeds()` and `UrlMetadataService.fetchMetadataForPending()`.

**Step 18: In-app sync timer**

- While app is running, sync feeds on a timer (1 hour).
- Also sync on app launch / foreground.
- Show sync status indicator in sidebar.

**Step 19: Remove dead code**

- Delete `APIClient.swift`.
- Delete all HTTP-based service files (`ConnectionService.swift`, `FeedService.swift`, `UriService.swift`, `TagService.swift`, `ImportService.swift`, `MetadataService.swift`).
- Delete `SettingsView.swift` (server URL config).
- Delete paginated response model types.
- Remove Settings scene from `ConnectionsApp.swift`.

**Step 20: Update Package.swift**

Final `Package.swift` dependencies:
```swift
dependencies: [
    .package(url: "https://github.com/nmdias/FeedKit.git", from: "9.1.2"),
    .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
]
```

Target platform: `.macOS(.v14)` (already set).

## Out of Scope

- Migration tool from existing SQLite database to SwiftData/CloudKit.
- Raycast client changes (remains backend-dependent).
- Backend server removal (stays for Raycast and potential other clients).
- Conflict resolution strategy for CloudKit sync (SwiftData/CloudKit handles this automatically with last-writer-wins).
