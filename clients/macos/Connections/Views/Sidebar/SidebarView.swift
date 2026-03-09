import SwiftUI
import SwiftData

// What the user can select in the sidebar
enum SidebarSelection: Hashable {
    case uriFilter(UriFilterCard)
    case connection(CDConnection)

    static func == (lhs: SidebarSelection, rhs: SidebarSelection) -> Bool {
        switch (lhs, rhs) {
        case (.uriFilter(let a), .uriFilter(let b)): a == b
        case (.connection(let a), .connection(let b)): a.uid == b.uid
        default: false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .uriFilter(let card): hasher.combine("filter"); hasher.combine(card)
        case .connection(let conn): hasher.combine("connection"); hasher.combine(conn.uid)
        }
    }
}

enum UriFilterCard: String, Hashable, CaseIterable {
    case unread, readLater, upvoted, inbox

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
    @Environment(\.modelContext) private var modelContext
    @Environment(FeedSyncService.self) private var feedSyncService

    @Query(sort: \CDConnection.name) private var connections: [CDConnection]

    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var showImportSheet = false

    private var filteredConnections: [CDConnection] {
        if searchText.isEmpty { return connections }
        return connections.filter { $0.name.localizedStandardContains(searchText) }
    }

    private var unreadCount: Int { UriStore.countUnread(in: modelContext) }
    private var readLaterCount: Int { UriStore.countReadLater(in: modelContext) }
    private var upvotedCount: Int { UriStore.countUpvoted(in: modelContext) }
    private var inboxCount: Int { UriStore.countOrphan(in: modelContext) }

    var body: some View {
        VStack(spacing: 0) {
            cardGrid
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 24)

            List(selection: Binding(
                get: { connectionFromSelection },
                set: { conn in
                    if let conn { selection = .connection(conn) }
                }
            )) {
                Section("Connections") {
                    ForEach(filteredConnections) { connection in
                        ConnectionSidebarRow(connection: connection)
                            .tag(connection)
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, prompt: "Search connections...")
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
            ToolbarItem(id: "sync", placement: .secondaryAction) {
                Button {
                    Task { await feedSyncService.syncAllFeeds(context: modelContext) }
                } label: {
                    if feedSyncService.isSyncing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(feedSyncService.isSyncing)
                .help("Sync all feeds")
            }
        }
        .navigationTitle("Connections")
        .sheet(isPresented: $showCreateSheet) {
            ConnectionCreateView()
        }
        .sheet(isPresented: $showImportSheet) {
            ImportOpmlView()
        }
    }

    private var cardGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                FilterCardView(card: .unread, count: unreadCount, isSelected: isCardSelected(.unread)) {
                    selection = .uriFilter(.unread)
                }
                FilterCardView(card: .readLater, count: readLaterCount, isSelected: isCardSelected(.readLater)) {
                    selection = .uriFilter(.readLater)
                }
            }
            GridRow {
                FilterCardView(card: .upvoted, count: upvotedCount, isSelected: isCardSelected(.upvoted)) {
                    selection = .uriFilter(.upvoted)
                }
                FilterCardView(card: .inbox, count: inboxCount, isSelected: isCardSelected(.inbox)) {
                    selection = .uriFilter(.inbox)
                }
            }
        }
    }

    private var connectionFromSelection: CDConnection? {
        if case .connection(let conn) = selection { return conn }
        return nil
    }

    private func isCardSelected(_ card: UriFilterCard) -> Bool {
        if case .uriFilter(let selected) = selection { return selected == card }
        return false
    }
}

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

struct ConnectionSidebarRow: View {
    let connection: CDConnection

    var body: some View {
        HStack(spacing: 8) {
            if let photo = connection.photo, let url = URL(string: photo) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill").foregroundStyle(.secondary)
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }

            Text(connection.name).lineLimit(1)
            Spacer()

            if connection.unreadUriCount > 0 {
                Text("\(connection.unreadUriCount)")
                    .font(.caption2).fontWeight(.medium)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 1)
    }
}
