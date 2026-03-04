import SwiftUI

enum UriListMode {
    case all, unread, readLater, upvoted, downvoted, inbox

    var title: String {
        switch self {
        case .all: "All URIs"
        case .unread: "Unread"
        case .readLater: "Read Later"
        case .upvoted: "Upvoted"
        case .downvoted: "Downvoted"
        case .inbox: "Inbox"
        }
    }
}

struct UriListView: View {
    let mode: UriListMode

    @State private var uris: [UriEntry] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var page = 1
    @State private var hasMore = false
    @State private var error: String?
    @State private var selectedUri: UriEntry?
    @State private var showCreateSheet = false

    var body: some View {
        List(selection: $selectedUri) {
            ForEach(uris) { uri in
                UriRowView(uri: uri, onRefresh: loadUris)
            }

            if hasMore {
                Button("Load More") { loadMore() }
                    .frame(maxWidth: .infinity)
            }
        }
        .searchable(text: $searchText, prompt: "Search URIs...")
        .onChange(of: searchText) { _, _ in
            Task { await search() }
        }
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Create URI", systemImage: "plus") {
                    showCreateSheet = true
                }
            }
            if mode == .unread {
                ToolbarItem {
                    Button("Mark All Read", systemImage: "checkmark.circle") {
                        markAllRead()
                    }
                }
            }
            ToolbarItem {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    loadUris()
                }
            }
        }
        .overlay {
            if isLoading && uris.isEmpty {
                ProgressView()
            } else if let error {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if uris.isEmpty && !isLoading {
                ContentUnavailableView("No URIs", systemImage: "doc.text", description: Text("No URIs found"))
            }
        }
        .task { loadUris() }
        .sheet(isPresented: $showCreateSheet) {
            CreateUriView(onCreated: loadUris)
        }
    }

    private func loadUris() {
        page = 1
        isLoading = true
        error = nil
        Task {
            do {
                let response = try await fetchUris(page: 1)
                await MainActor.run {
                    uris = response.data
                    hasMore = response.page < response.totalPages
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func loadMore() {
        page += 1
        Task {
            do {
                let response = try await fetchUris(page: page)
                await MainActor.run {
                    uris.append(contentsOf: response.data)
                    hasMore = response.page < response.totalPages
                }
            } catch {
                await MainActor.run { page -= 1 }
            }
        }
    }

    private func search() async {
        page = 1
        do {
            let response = try await fetchUris(page: 1)
            await MainActor.run {
                uris = response.data
                hasMore = response.page < response.totalPages
            }
        } catch {}
    }

    private func fetchUris(page: Int) async throws -> UrisResponse {
        try await UriService.listAll(
            page: page,
            query: searchText.isEmpty ? nil : searchText,
            unread: mode == .unread,
            readLater: mode == .readLater,
            upvoted: mode == .upvoted,
            downvoted: mode == .downvoted,
            orphan: mode == .inbox
        )
    }

    private func markAllRead() {
        Task {
            _ = try? await UriService.markAllReadGlobal()
            await MainActor.run { loadUris() }
        }
    }
}
