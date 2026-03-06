import SwiftUI

// What the user can select in the sidebar: either a URI filter card or a connection
enum SidebarSelection: Hashable {
    case uriFilter(UriFilterCard)
    case connection(Connection)
}

// The four top-level URI filter cards (Reminders-style)
enum UriFilterCard: String, Hashable, CaseIterable {
    case unread
    case readLater
    case upvoted
    case inbox

    var title: String {
        switch self {
        case .unread: "Unread"
        case .readLater: "Read Later"
        case .upvoted: "Upvoted"
        case .inbox: "Inbox"
        }
    }

    var icon: String {
        switch self {
        case .unread: "circle.fill"
        case .readLater: "clock.fill"
        case .upvoted: "arrow.up.circle.fill"
        case .inbox: "tray.fill"
        }
    }

    var color: Color {
        switch self {
        case .unread: .blue
        case .readLater: .orange
        case .upvoted: .green
        case .inbox: .gray
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    @State private var searchText = ""
    @State private var connections: [Connection] = []
    @State private var isLoading = false
    @State private var page = 1
    @State private var hasMore = false
    @State private var showCreateSheet = false
    @State private var showImportSheet = false

    // URI counts for the filter cards
    @State private var unreadCount = 0
    @State private var readLaterCount = 0
    @State private var upvotedCount = 0
    @State private var inboxCount = 0

    var body: some View {
        VStack(spacing: 0) {
            // Card grid
            cardGrid
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Connection list
            List(selection: Binding(
                get: { connectionFromSelection },
                set: { conn in
                    if let conn {
                        selection = .connection(conn)
                    }
                }
            )) {
                Section("Connections") {
                    ForEach(connections) { connection in
                        ConnectionSidebarRow(connection: connection)
                            .tag(connection)
                    }

                    if hasMore {
                        Button("Load More") { loadMore() }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: "Search connections...")
            .onChange(of: searchText) { _, _ in
                Task { await search() }
            }
        }
        .toolbar(id: "sidebar") {
            ToolbarItem(id: "add", placement: .primaryAction) {
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
        }
        .navigationTitle("Connections")
        .task {
            loadConnections()
            await loadCounts()
        }
        .sheet(isPresented: $showCreateSheet) {
            ConnectionCreateView(onCreated: {
                loadConnections()
                Task { await loadCounts() }
            })
        }
        .sheet(isPresented: $showImportSheet) {
            ImportOpmlView(onImported: {
                loadConnections()
                Task { await loadCounts() }
            })
        }
    }

    // MARK: - Card Grid

    private var cardGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                FilterCardView(
                    card: .unread,
                    count: unreadCount,
                    isSelected: isCardSelected(.unread)
                ) {
                    selection = .uriFilter(.unread)
                }
                FilterCardView(
                    card: .readLater,
                    count: readLaterCount,
                    isSelected: isCardSelected(.readLater)
                ) {
                    selection = .uriFilter(.readLater)
                }
            }
            GridRow {
                FilterCardView(
                    card: .upvoted,
                    count: upvotedCount,
                    isSelected: isCardSelected(.upvoted)
                ) {
                    selection = .uriFilter(.upvoted)
                }
                FilterCardView(
                    card: .inbox,
                    count: inboxCount,
                    isSelected: isCardSelected(.inbox)
                ) {
                    selection = .uriFilter(.inbox)
                }
            }
        }
    }

    // MARK: - Helpers

    private var connectionFromSelection: Connection? {
        if case .connection(let conn) = selection { return conn }
        return nil
    }

    private func isCardSelected(_ card: UriFilterCard) -> Bool {
        if case .uriFilter(let selected) = selection { return selected == card }
        return false
    }

    // MARK: - Data Loading

    func loadConnections() {
        page = 1
        isLoading = true
        Task {
            do {
                let response = try await ConnectionService.list(page: 1, query: searchText.isEmpty ? nil : searchText)
                await MainActor.run {
                    connections = response.data
                    hasMore = response.page < response.totalPages
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }

    func loadCounts() async {
        async let unreadResult = UriService.listAll(page: 1, query: nil, unread: true, perPage: 1)
        async let readLaterResult = UriService.listAll(page: 1, query: nil, readLater: true, perPage: 1)
        async let upvotedResult = UriService.listAll(page: 1, query: nil, upvoted: true, perPage: 1)
        async let inboxResult = UriService.listAll(page: 1, query: nil, orphan: true, perPage: 1)

        let unread = (try? await unreadResult)?.total ?? 0
        let readLater = (try? await readLaterResult)?.total ?? 0
        let upvoted = (try? await upvotedResult)?.total ?? 0
        let inbox = (try? await inboxResult)?.total ?? 0

        await MainActor.run {
            unreadCount = unread
            readLaterCount = readLater
            upvotedCount = upvoted
            inboxCount = inbox
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

// MARK: - Filter Card

struct FilterCardView: View {
    let card: UriFilterCard
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: card.icon)
                        .font(.title2)
                        .foregroundStyle(card.color)
                    Spacer()
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                Text(card.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? card.color.opacity(0.12) : Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? card.color.opacity(0.4) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Connection Sidebar Row

struct ConnectionSidebarRow: View {
    let connection: Connection

    var body: some View {
        HStack(spacing: 8) {
            if let photo = connection.photo, let url = URL(string: photo) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }

            Text(connection.name)
                .lineLimit(1)

            Spacer()

            if connection.unreadUriCount > 0 {
                Text("\(connection.unreadUriCount)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 1)
    }
}
