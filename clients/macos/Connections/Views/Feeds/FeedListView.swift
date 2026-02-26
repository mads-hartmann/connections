import SwiftUI

struct FeedListView: View {
    let connectionId: Int
    let connectionName: String

    @State private var feeds: [Feed] = []
    @State private var isLoading = false
    @State private var page = 1
    @State private var hasMore = false
    @State private var showCreateSheet = false

    var body: some View {
        List {
            ForEach(feeds) { feed in
                FeedRowView(feed: feed, connectionId: connectionId, onRefresh: loadFeeds)
            }

            if hasMore {
                Button("Load More") { loadMore() }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("\(connectionName) — Feeds")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Feed", systemImage: "plus") {
                    showCreateSheet = true
                }
            }
        }
        .overlay {
            if isLoading && feeds.isEmpty {
                ProgressView()
            } else if feeds.isEmpty && !isLoading {
                ContentUnavailableView("No Feeds", systemImage: "list.bullet", description: Text("Add a feed to get started"))
            }
        }
        .task { loadFeeds() }
        .sheet(isPresented: $showCreateSheet) {
            FeedCreateView(connectionId: connectionId, onCreated: loadFeeds)
        }
    }

    private func loadFeeds() {
        page = 1
        isLoading = true
        Task {
            do {
                let response = try await FeedService.listByConnection(connectionId: connectionId, page: 1)
                await MainActor.run {
                    feeds = response.data
                    hasMore = response.page < response.totalPages
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func loadMore() {
        page += 1
        Task {
            do {
                let response = try await FeedService.listByConnection(connectionId: connectionId, page: page)
                await MainActor.run {
                    feeds.append(contentsOf: response.data)
                    hasMore = response.page < response.totalPages
                }
            } catch {
                await MainActor.run { page -= 1 }
            }
        }
    }
}

struct FeedRowView: View {
    let feed: Feed
    let connectionId: Int
    let onRefresh: () -> Void

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var showUris = false

    var body: some View {
        NavigationLink(value: feed) {
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.title ?? feed.url)
                    .fontWeight(.medium)
                Text(feed.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let lastFetched = feed.lastFetchedAt {
                    Text("Last fetched: \(DateFormatting.formatWithTime(lastFetched))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 2)
        }
        .contextMenu {
            Button("View URIs") { showUris = true }
            Button("Refresh Feed") { refreshFeed() }
            Divider()
            Button("Edit") { showEditSheet = true }
            Button("Delete", role: .destructive) { showDeleteConfirm = true }
        }
        .navigationDestination(isPresented: $showUris) {
            FeedUriListView(feed: feed)
        }
        .sheet(isPresented: $showEditSheet) {
            FeedEditView(feed: feed, onSaved: onRefresh)
        }
        .confirmationDialog("Delete \"\(feed.title ?? feed.url)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteFeed() }
        }
    }

    private func refreshFeed() {
        Task {
            _ = try? await FeedService.refresh(id: feed.id)
            await MainActor.run { onRefresh() }
        }
    }

    private func deleteFeed() {
        Task {
            try? await FeedService.delete(id: feed.id)
            await MainActor.run { onRefresh() }
        }
    }
}

struct FeedUriListView: View {
    let feed: Feed

    @State private var uris: [UriEntry] = []
    @State private var isLoading = false
    @State private var page = 1
    @State private var hasMore = false

    var body: some View {
        List {
            ForEach(uris) { uri in
                UriRowView(uri: uri, onRefresh: loadUris)
            }

            if hasMore {
                Button("Load More") { loadMore() }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(feed.title ?? "Feed URIs")
        .toolbar {
            ToolbarItem {
                Button("Mark All Read", systemImage: "checkmark.circle") {
                    markAllRead()
                }
            }
        }
        .overlay {
            if isLoading && uris.isEmpty {
                ProgressView()
            } else if uris.isEmpty && !isLoading {
                ContentUnavailableView("No URIs", systemImage: "doc.text")
            }
        }
        .task { loadUris() }
    }

    private func loadUris() {
        page = 1
        isLoading = true
        Task {
            do {
                let response = try await UriService.listByFeed(feedId: feed.id, page: 1)
                await MainActor.run {
                    uris = response.data
                    hasMore = response.page < response.totalPages
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func loadMore() {
        page += 1
        Task {
            do {
                let response = try await UriService.listByFeed(feedId: feed.id, page: page)
                await MainActor.run {
                    uris.append(contentsOf: response.data)
                    hasMore = response.page < response.totalPages
                }
            } catch {
                await MainActor.run { page -= 1 }
            }
        }
    }

    private func markAllRead() {
        Task {
            _ = try? await UriService.markAllReadByFeed(feedId: feed.id)
            await MainActor.run { loadUris() }
        }
    }
}
