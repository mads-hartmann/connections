import SwiftUI

struct ConnectionListView: View {
    @State private var connections: [Connection] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var page = 1
    @State private var hasMore = false
    @State private var error: String?
    @State private var selectedConnection: Connection?
    @State private var showCreateSheet = false
    @State private var showImportSheet = false

    var body: some View {
        NavigationStack {
            List(selection: $selectedConnection) {
                let withUnread = connections.filter { $0.unreadUriCount > 0 }
                let withoutUnread = connections.filter { $0.unreadUriCount == 0 }

                if !withUnread.isEmpty {
                    let totalUnread = withUnread.reduce(0) { $0 + $1.unreadUriCount }
                    Section("Unread (\(totalUnread))") {
                        ForEach(withUnread) { connection in
                            ConnectionRowView(connection: connection, onRefresh: loadConnections)
                        }
                    }
                }

                if !withoutUnread.isEmpty {
                    Section("All") {
                        ForEach(withoutUnread) { connection in
                            ConnectionRowView(connection: connection, onRefresh: loadConnections)
                        }
                    }
                }

                if hasMore {
                    Button("Load More") { loadMore() }
                        .frame(maxWidth: .infinity)
                }
            }
            .searchable(text: $searchText, prompt: "Search connections...")
            .onChange(of: searchText) { _, _ in
                Task { await search() }
            }
            .navigationTitle("Connections")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Create Connection", systemImage: "plus") {
                            showCreateSheet = true
                        }
                        Button("Import OPML", systemImage: "square.and.arrow.down") {
                            showImportSheet = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        loadConnections()
                    }
                }
            }
            .overlay {
                if isLoading && connections.isEmpty {
                    ProgressView()
                } else if let error {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if connections.isEmpty && !isLoading {
                    ContentUnavailableView("No Connections", systemImage: "person.2", description: Text("Create a connection to get started"))
                }
            }
            .task { loadConnections() }
            .sheet(isPresented: $showCreateSheet) {
                ConnectionCreateView(onCreated: loadConnections)
            }
            .sheet(isPresented: $showImportSheet) {
                ImportOpmlView(onImported: loadConnections)
            }
        }
    }

    private func loadConnections() {
        page = 1
        isLoading = true
        error = nil
        Task {
            do {
                let response = try await ConnectionService.list(page: 1, query: searchText.isEmpty ? nil : searchText)
                await MainActor.run {
                    connections = response.data
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
                let response = try await ConnectionService.list(page: page, query: searchText.isEmpty ? nil : searchText)
                await MainActor.run {
                    connections.append(contentsOf: response.data)
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
            let response = try await ConnectionService.list(page: 1, query: searchText.isEmpty ? nil : searchText)
            await MainActor.run {
                connections = response.data
                hasMore = response.page < response.totalPages
            }
        } catch {}
    }
}
