import SwiftUI

struct ContentView: View {
    @State private var selection: SidebarSelection? = .uriFilter(.unread)

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .uriFilter(let card):
                UriListView(mode: card.listMode)
            case .connection(let connection):
                ConnectionDetailPaneView(connection: connection)
            case nil:
                Text("Select a section")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .focusable()
        .onKeyPress(.init("1"), modifiers: .command) {
            selection = .uriFilter(.unread)
            return .handled
        }
        .onKeyPress(.init("2"), modifiers: .command) {
            selection = .uriFilter(.readLater)
            return .handled
        }
        .onKeyPress(.init("3"), modifiers: .command) {
            selection = .uriFilter(.upvoted)
            return .handled
        }
        .onKeyPress(.init("4"), modifiers: .command) {
            selection = .uriFilter(.inbox)
            return .handled
        }
    }
}

extension UriFilterCard {
    var listMode: UriListMode {
        switch self {
        case .unread: .unread
        case .readLater: .readLater
        case .upvoted: .upvoted
        case .inbox: .inbox
        }
    }
}
