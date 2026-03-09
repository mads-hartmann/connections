import SwiftUI
import SwiftData

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

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var showCreateSheet = false

    private var uris: [CDUri] {
        UriStore.listAll(
            in: modelContext,
            query: searchText.isEmpty ? nil : searchText,
            unreadOnly: mode == .unread,
            readLaterOnly: mode == .readLater,
            upvotedOnly: mode == .upvoted,
            downvotedOnly: mode == .downvoted,
            orphanOnly: mode == .inbox
        )
    }

    var body: some View {
        NavigationStack {
        List {
            ForEach(uris) { uri in
                UriRowView(uri: uri)
            }
        }
        .navigationDestination(for: UUID.self) { uid in
            if let uri = UriStore.get(in: modelContext, uid: uid) {
                UriDetailView(uri: uri)
            }
        }
        .searchable(text: $searchText, prompt: "Search URIs...")
        .navigationTitle(mode.title)
        .toolbar(id: "uriList") {
            ToolbarItem(id: "createUri", placement: .primaryAction) {
                Button("Create URI", systemImage: "plus") {
                    showCreateSheet = true
                }
            }
            ToolbarItem(id: "markAllRead", placement: .secondaryAction) {
                Button("Mark All Read", systemImage: "checkmark.circle") {
                    _ = UriStore.markAllReadGlobal(in: modelContext)
                }
                .opacity(mode == .unread ? 1 : 0)
                .disabled(mode != .unread)
            }
        }
        .overlay {
            if uris.isEmpty {
                ContentUnavailableView("No URIs", systemImage: "doc.text", description: Text("No URIs found"))
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateUriView()
        }
        } // NavigationStack
    }
}
