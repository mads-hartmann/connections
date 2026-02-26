import SwiftUI

enum SidebarSection: Hashable {
    case connections
    case urisAll
    case urisUnread
    case urisReadLater
    case urisUpvoted
    case urisDownvoted
    case urisInbox
    case tags

    var title: String {
        switch self {
        case .connections: "Connections"
        case .urisAll: "All"
        case .urisUnread: "Unread"
        case .urisReadLater: "Read Later"
        case .urisUpvoted: "Upvoted"
        case .urisDownvoted: "Downvoted"
        case .urisInbox: "Inbox"
        case .tags: "Tags"
        }
    }

    var icon: String {
        switch self {
        case .connections: "person.2"
        case .urisAll: "doc.text"
        case .urisUnread: "circle"
        case .urisReadLater: "clock"
        case .urisUpvoted: "arrow.up"
        case .urisDownvoted: "arrow.down"
        case .urisInbox: "tray"
        case .tags: "tag"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarSection?

    var body: some View {
        List(selection: $selection) {
            Section("People") {
                Label(SidebarSection.connections.title, systemImage: SidebarSection.connections.icon)
                    .tag(SidebarSection.connections)
            }

            Section("URIs") {
                Label(SidebarSection.urisAll.title, systemImage: SidebarSection.urisAll.icon)
                    .tag(SidebarSection.urisAll)
                Label(SidebarSection.urisUnread.title, systemImage: SidebarSection.urisUnread.icon)
                    .tag(SidebarSection.urisUnread)
                Label(SidebarSection.urisReadLater.title, systemImage: SidebarSection.urisReadLater.icon)
                    .tag(SidebarSection.urisReadLater)
                Label(SidebarSection.urisUpvoted.title, systemImage: SidebarSection.urisUpvoted.icon)
                    .tag(SidebarSection.urisUpvoted)
                Label(SidebarSection.urisDownvoted.title, systemImage: SidebarSection.urisDownvoted.icon)
                    .tag(SidebarSection.urisDownvoted)
                Label(SidebarSection.urisInbox.title, systemImage: SidebarSection.urisInbox.icon)
                    .tag(SidebarSection.urisInbox)
            }

            Section("Organize") {
                Label(SidebarSection.tags.title, systemImage: SidebarSection.tags.icon)
                    .tag(SidebarSection.tags)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Connections")
    }
}
