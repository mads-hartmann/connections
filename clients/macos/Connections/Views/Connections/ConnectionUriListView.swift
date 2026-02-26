import SwiftUI

struct ConnectionUriListView: View {
    let connection: Connection

    @State private var uris: [UriEntry] = []
    @State private var isLoading = false
    @State private var page = 1
    @State private var hasMore = false
    @State private var showUnreadOnly: Bool
    @State private var selectedUri: UriEntry?

    init(connection: Connection) {
        self.connection = connection
        self._showUnreadOnly = State(initialValue: connection.unreadUriCount > 0)
    }

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
        .navigationTitle("\(connection.name) — URIs")
        .toolbar {
            ToolbarItem {
                Picker("Filter", selection: $showUnreadOnly) {
                    Text("All").tag(false)
                    Text("Unread").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: showUnreadOnly) { _, _ in loadUris() }
            }
        }
        .overlay {
            if isLoading && uris.isEmpty {
                ProgressView()
            } else if uris.isEmpty && !isLoading {
                ContentUnavailableView("No URIs", systemImage: "doc.text", description: Text("No URIs found"))
            }
        }
        .task { loadUris() }
    }

    private func loadUris() {
        page = 1
        isLoading = true
        Task {
            do {
                let response = try await UriService.listByConnection(
                    connectionId: connection.id, page: 1, unread: showUnreadOnly
                )
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
                let response = try await UriService.listByConnection(
                    connectionId: connection.id, page: page, unread: showUnreadOnly
                )
                await MainActor.run {
                    uris.append(contentsOf: response.data)
                    hasMore = response.page < response.totalPages
                }
            } catch {
                await MainActor.run { page -= 1 }
            }
        }
    }
}
