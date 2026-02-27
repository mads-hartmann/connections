# Native macOS Client Specification

## Problem Statement

The Connections app currently only has a Raycast extension as its client. This limits usage to Raycast users. A native macOS SwiftUI application will provide a standalone client with full feature parity, accessible to anyone running macOS.

## Requirements

### Technology

- **SwiftUI** targeting macOS 14+ (Sonoma)
- **Swift 5.9+**
- Xcode project located at `clients/macos/`
- No third-party dependencies — use Foundation `URLSession` for networking

### Feature Parity with Raycast Extension

The macOS app must support all functionality present in the Raycast extension:

#### 1. Main Navigation

A sidebar-based NavigationSplitView with these sections:

| Section | Description |
|---------|-------------|
| Connections | List all connections (people), grouped by unread/all |
| URIs — All | All URIs across all connections |
| URIs — Unread | Unread URIs only |
| URIs — Read Later | URIs marked for later reading |
| URIs — Upvoted | Upvoted URIs |
| URIs — Downvoted | Downvoted URIs |
| URIs — Inbox | Orphan URIs (no connection) |
| Tags | All tags |

#### 2. Connections

- **List** connections with name, photo, unread count
- **Search/filter** connections by name
- **Create** connection from URL (fetches metadata, discovers feeds and social profiles, lets user select which to import)
- **Edit** connection name and photo URL
- **Edit note** (markdown text field)
- **Delete** connection (with confirmation)
- **View URIs** for a connection (with unread/all filter)
- **View feeds** for a connection
- **Add metadata** (social links: Bluesky, Email, GitHub, LinkedIn, Mastodon, Website, X, Other)
- **Refresh from website** (fetches metadata preview, lets user select name/photo/feed/profile updates to apply)
- **Mark all URIs as read** for a connection
- **Detail view** showing metadata fields, tags, note, feed/URI counts

#### 3. URIs

- **List** URIs with title, author/connection name, published date, read/unread icon, vote icon
- **Search/filter** URIs by text query
- **Detail view** showing full content (fetched via `/uris/:id/content`), OG metadata, tags, author, dates, note
- **Open in browser**
- **Mark as read / unread**
- **Mark as read later / remove from read later**
- **Upvote / downvote / remove vote**
- **Edit URI** (title, kind, connection assignment)
- **Edit note**
- **Delete** (with confirmation)
- **Refresh metadata** (re-fetch OG data)
- **Copy URL** to clipboard
- **Mark all as read** (global, per-feed, per-connection)
- **Create URI** from URL (fetches metadata, matches connections by host, lets user set title/kind/connection)

#### 4. Feeds

- **List** feeds for a connection (title, URL, last fetched date)
- **Create** feed (URL + title)
- **Edit** feed (URL + title)
- **Delete** feed (with confirmation)
- **Refresh** feed (trigger fetch)
- **View URIs** for a feed
- **View/manage tags** on a feed

#### 5. Tags

- **List** all tags with search
- **Create** tag
- **Edit/rename** tag
- **Delete** tag (with confirmation)
- **View URIs** filtered by tag
- **Add/remove tags** on connections, feeds, and URIs

#### 6. OPML Import

- **File picker** to select `.opml` file
- **Preview** parsed connections with feed counts and tags
- **Select/deselect** individual connections
- **Confirm import** and show results (created connections, feeds, tags)

### Server Configuration

- Configurable server URL (default: `http://localhost:8080`)
- Stored in `UserDefaults` or a Settings scene
- Health check on launch to verify server connectivity

## Data Models (Swift)

These mirror the JSON responses from the server API:

```swift
struct Connection: Codable, Identifiable {
    let id: Int
    var name: String
    var photo: String?
    var note: String?
    let feedCount: Int
    let uriCount: Int
    let unreadUriCount: Int
    var metadata: [ConnectionMetadata]
    var tags: [Tag]
}

struct ConnectionMetadata: Codable, Identifiable {
    let id: Int
    let fieldType: MetadataFieldType
    var value: String
}

struct MetadataFieldType: Codable, Identifiable {
    let id: Int
    let name: String
}

struct Feed: Codable, Identifiable {
    let id: Int
    let connectionId: Int
    var url: String
    var title: String?
    let createdAt: String
    let lastFetchedAt: String?
}

struct UriEntry: Codable, Identifiable {
    let id: Int
    let feedId: Int?
    let connectionId: Int?
    let connectionName: String?
    var kind: UriKind
    var title: String?
    let url: String
    let publishedAt: String?
    let content: String?
    let author: String?
    let imageUrl: String?
    let createdAt: String
    var readAt: String?
    var readLaterAt: String?
    var tags: [Tag]
    let ogTitle: String?
    let ogDescription: String?
    let ogImage: String?
    let ogSiteName: String?
    let ogFetchedAt: String?
    let ogFetchError: String?
    var vote: Int?
    let votedAt: String?
    var note: String?
}

enum UriKind: String, Codable, CaseIterable {
    case blog, video, tweet, book, site, podcast, paper, unknown
}

struct Tag: Codable, Identifiable {
    let id: Int
    var name: String
}
```

## Architecture

```
clients/macos/
├── Connections.xcodeproj/
├── Connections/
│   ├── ConnectionsApp.swift          # App entry point, WindowGroup + Settings
│   ├── Models/                       # Codable data models
│   ├── Services/
│   │   └── APIClient.swift           # URLSession-based HTTP client
│   ├── Views/
│   │   ├── Sidebar.swift             # NavigationSplitView sidebar
│   │   ├── Connections/              # Connection list, detail, forms
│   │   ├── URIs/                     # URI list, detail, forms
│   │   ├── Feeds/                    # Feed list, forms
│   │   ├── Tags/                     # Tag list, forms
│   │   ├── Import/                   # OPML import flow
│   │   └── Settings/                 # Server URL configuration
│   └── Utilities/
│       └── DateFormatting.swift
└── README.md
```

### API Client

A single `APIClient` class wrapping `URLSession` with:
- Configurable base URL from settings
- JSON encoding/decoding with `snakeCase` key strategy
- Generic request methods: `get`, `post`, `put`, `patch`, `delete`
- Paginated list fetching support
- Error handling that surfaces server error messages

### Navigation Pattern

- `NavigationSplitView` with a sidebar listing sections
- Sidebar selection drives the detail column content
- Forms presented as sheets (`.sheet` modifier) for create/edit operations
- Confirmation dialogs for destructive actions (`.confirmationDialog`)

## Acceptance Criteria

1. App launches and connects to the configured server
2. All connections are listed with photo, name, unread count; searchable
3. Connection detail shows metadata, tags, note, feed/URI counts
4. Connections can be created from URL with metadata discovery
5. Connections can be edited (name, photo, note) and deleted
6. Connection metadata (social links) can be added, edited, deleted
7. Connection metadata can be refreshed from website
8. All URI views work: all, unread, read later, upvoted, downvoted, inbox
9. URIs are listed with title, author, date, read status, vote status; searchable
10. URI detail shows full content (markdown), OG metadata, tags, note
11. URIs can be marked read/unread, read later, upvoted/downvoted
12. URIs can be created from URL with metadata fetch and connection matching
13. URIs can be edited (title, kind, connection) and deleted
14. URI notes can be edited
15. Feeds are listed per connection; can be created, edited, deleted, refreshed
16. Tags are listed, searchable; can be created, renamed, deleted
17. Tags can be added/removed from connections, feeds, and URIs
18. OPML import works: file pick, preview, select, confirm
19. Server URL is configurable in Settings
20. Pagination works for all list views (load more on scroll)
21. All destructive actions require confirmation

## Implementation Approach

### Phase 1: Project Setup & API Client

1. Create Xcode project structure at `clients/macos/`
2. Define all Swift data models with `Codable` conformance and `snakeCase` decoding
3. Implement `APIClient` with generic HTTP methods and pagination support
4. Implement all API endpoint functions (connections, URIs, feeds, tags, import, metadata discovery)
5. Add Settings view for server URL configuration

### Phase 2: Read-Only Views

6. Build sidebar navigation with all sections
7. Implement connection list view with search, unread grouping, and pagination
8. Implement connection detail view (metadata, tags, note)
9. Implement URI list view with search, filtering, and pagination
10. Implement URI detail view with content fetching and metadata display
11. Implement feed list view per connection
12. Implement tag list view with search

### Phase 3: Create/Edit/Delete Operations

13. Connection create form (URL fetch → preview → confirm with feeds/profiles)
14. Connection edit form (name, photo)
15. Connection note editor
16. Connection delete with confirmation
17. URI create form (URL fetch → metadata → kind/connection selection)
18. URI edit form (title, kind, connection)
19. URI note editor
20. URI actions: mark read/unread, read later, vote, refresh metadata, delete
21. Feed create/edit/delete forms
22. Tag create/rename/delete
23. Tag association management (add/remove on connections, feeds, URIs)

### Phase 4: Advanced Features

24. Connection metadata management (add/edit/delete social links)
25. Connection refresh from website (preview → select updates → apply)
26. OPML import flow (file picker → preview → select → confirm)
27. Mark all as read (global, per-connection, per-feed)

### Phase 5: Polish

28. Keyboard shortcuts for common actions
29. Error handling and user-facing error messages
30. Loading states and empty states
31. Add `README.md` with build instructions
