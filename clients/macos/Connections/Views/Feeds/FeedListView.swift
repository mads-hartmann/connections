import SwiftUI
import SwiftData

struct FeedListView: View {
    let connection: CDConnection

    @Environment(\.modelContext) private var modelContext
    @Environment(FeedSyncService.self) private var feedSyncService
    @State private var showCreateSheet = false

    private var feeds: [CDFeed] {
        FeedStore.listByConnection(connection)
    }

    var body: some View {
        List {
            ForEach(feeds) { feed in
                FeedRowView(feed: feed)
            }
        }
        .navigationTitle("\(connection.name) — Feeds")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Feed", systemImage: "plus") {
                    showCreateSheet = true
                }
            }
        }
        .overlay {
            if feeds.isEmpty {
                ContentUnavailableView("No Feeds", systemImage: "list.bullet", description: Text("Add a feed to get started"))
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            FeedCreateView(connection: connection)
        }
    }
}

struct FeedRowView: View {
    let feed: CDFeed

    @Environment(\.modelContext) private var modelContext
    @Environment(FeedSyncService.self) private var feedSyncService
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var showUris = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(feed.title ?? feed.url).fontWeight(.medium)
            Text(feed.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if let lastFetched = feed.lastFetchedAt {
                Text("Last fetched: \(DateFormatting.formatDateWithTime(lastFetched))")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("View URIs") { showUris = true }
            Button("Refresh Feed") {
                Task { @MainActor in
                    await feedSyncService.refreshFeed(feed, context: modelContext)
                }
            }
            Divider()
            Button("Edit") { showEditSheet = true }
            Button("Delete", role: .destructive) { showDeleteConfirm = true }
        }
        .navigationDestination(isPresented: $showUris) {
            FeedUriListView(feed: feed)
        }
        .sheet(isPresented: $showEditSheet) {
            FeedEditView(feed: feed)
        }
        .confirmationDialog("Delete \"\(feed.title ?? feed.url)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                FeedStore.delete(in: modelContext, feed: feed)
            }
        }
    }
}

struct FeedUriListView: View {
    let feed: CDFeed

    @Environment(\.modelContext) private var modelContext

    private var uris: [CDUri] {
        UriStore.listByFeed(feed)
    }

    var body: some View {
        List {
            ForEach(uris) { uri in
                UriRowView(uri: uri)
            }
        }
        .navigationTitle(feed.title ?? "Feed URIs")
        .toolbar {
            ToolbarItem {
                Button("Mark All Read", systemImage: "checkmark.circle") {
                    _ = UriStore.markAllReadByFeed(feed)
                }
            }
        }
        .overlay {
            if uris.isEmpty {
                ContentUnavailableView("No URIs", systemImage: "doc.text")
            }
        }
    }
}
