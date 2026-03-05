import SwiftUI

// FocusedValue key to expose the sidebar selection to menu commands
struct SidebarSelectionKey: FocusedValueKey {
    typealias Value = Binding<SidebarSelection?>
}

extension FocusedValues {
    var sidebarSelection: Binding<SidebarSelection?>? {
        get { self[SidebarSelectionKey.self] }
        set { self[SidebarSelectionKey.self] = newValue }
    }
}

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
        .focusedValue(\.sidebarSelection, $selection)
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
