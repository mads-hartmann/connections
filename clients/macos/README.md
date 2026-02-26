# Connections — macOS Client

A native SwiftUI macOS application for the Connections server.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+
- A running Connections server (default: `http://localhost:8080`)

## Building

Open the project in Xcode:

```bash
cd clients/macos
open Package.swift
```

Or build from the command line:

```bash
cd clients/macos
swift build
swift run Connections
```

## Configuration

On first launch, the app connects to `http://localhost:8080`. Change the server URL in **Connections → Settings** (⌘,).

## Features

- Browse connections, URIs, feeds, and tags
- Create connections from URL with automatic metadata discovery
- Read URI content inline with full article rendering
- Mark URIs as read/unread, read later, upvote/downvote
- Create URIs from URL with metadata fetch and connection matching
- Manage feeds per connection (create, edit, delete, refresh)
- Tag management with associations on connections, feeds, and URIs
- Import feeds from OPML files
- Refresh connection metadata from website
- Search and pagination across all list views

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘1 | Connections |
| ⌘2 | Unread URIs |
| ⌘3 | All URIs |
| ⌘4 | Tags |
| ⌘, | Settings |
