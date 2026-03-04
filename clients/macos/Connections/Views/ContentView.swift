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
        .keyboardShortcut("1", modifiers: .command, action: { selection = .uriFilter(.unread) })
        .keyboardShortcut("2", modifiers: .command, action: { selection = .uriFilter(.readLater) })
        .keyboardShortcut("3", modifiers: .command, action: { selection = .uriFilter(.upvoted) })
        .keyboardShortcut("4", modifiers: .command, action: { selection = .uriFilter(.inbox) })
    }
}

extension View {
    func keyboardShortcut(_ key: Character, modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        self.background(
            Button("") { action() }
                .keyboardShortcut(KeyEquivalent(key), modifiers: modifiers)
                .hidden()
        )
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
