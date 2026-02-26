import SwiftUI

struct ContentView: View {
    @State private var selection: SidebarSection? = .urisUnread

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .connections:
                ConnectionListView()
            case .urisAll:
                UriListView(mode: .all)
            case .urisUnread:
                UriListView(mode: .unread)
            case .urisReadLater:
                UriListView(mode: .readLater)
            case .urisUpvoted:
                UriListView(mode: .upvoted)
            case .urisDownvoted:
                UriListView(mode: .downvoted)
            case .urisInbox:
                UriListView(mode: .inbox)
            case .tags:
                TagListView()
            case nil:
                Text("Select a section")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        // Keyboard shortcuts for sidebar navigation
        .keyboardShortcut("1", modifiers: .command, action: { selection = .connections })
        .keyboardShortcut("2", modifiers: .command, action: { selection = .urisUnread })
        .keyboardShortcut("3", modifiers: .command, action: { selection = .urisAll })
        .keyboardShortcut("4", modifiers: .command, action: { selection = .tags })
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
