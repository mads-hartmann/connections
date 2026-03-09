import SwiftUI

struct SidebarSelectionKey: FocusedValueKey {
    typealias Value = Binding<SidebarSelection?>
}

struct SidebarVisibilityKey: FocusedValueKey {
    typealias Value = Binding<NavigationSplitViewVisibility>
}

extension FocusedValues {
    var sidebarSelection: Binding<SidebarSelection?>? {
        get { self[SidebarSelectionKey.self] }
        set { self[SidebarSelectionKey.self] = newValue }
    }

    var sidebarVisibility: Binding<NavigationSplitViewVisibility>? {
        get { self[SidebarVisibilityKey.self] }
        set { self[SidebarVisibilityKey.self] = newValue }
    }
}

struct ContentView: View {
    @State private var selection: SidebarSelection? = .uriFilter(.unread)
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(selection: $selection)
        } detail: {
            detailView
        }
        .frame(minWidth: 800, minHeight: 500)
        .focusedValue(\.sidebarSelection, $selection)
        .focusedValue(\.sidebarVisibility, $sidebarVisibility)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .uriFilter(let card):
            UriListView(mode: card.listMode)
                .id("uriFilter-\(card.rawValue)")
        case .connection(let connection):
            ConnectionDetailPaneView(connection: connection)
                .id("connection-\(connection.uid)")
        case nil:
            Text("Select a section")
                .foregroundStyle(.secondary)
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
