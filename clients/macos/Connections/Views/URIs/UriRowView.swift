import SwiftUI
import SwiftData

struct UriRowView: View {
    let uri: CDUri

    @Environment(\.modelContext) private var modelContext
    @State private var showNoteSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationLink(value: uri.uid) {
            HStack(spacing: 8) {
                Circle()
                    .fill(uri.isRead ? .clear : .blue)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(uri.displayTitle)
                        .fontWeight(uri.isRead ? .regular : .medium)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let name = uri.connectionName ?? uri.author {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let date = uri.publishedAt {
                            Text(DateFormatting.formatDate(date))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    if uri.isReadLater {
                        Image(systemName: "clock").font(.caption).foregroundStyle(.orange)
                    }
                    if uri.isUpvoted {
                        Image(systemName: "arrow.up").font(.caption).foregroundStyle(.green)
                    }
                    if uri.isDownvoted {
                        Image(systemName: "arrow.down").font(.caption).foregroundStyle(.red)
                    }
                    if !uri.tags.isEmpty {
                        Image(systemName: "tag").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .contextMenu {
            Button("Open in Browser") {
                if let url = URL(string: uri.url) { NSWorkspace.shared.open(url) }
            }
            Divider()
            Button(uri.isRead ? "Mark as Unread" : "Mark as Read") {
                UriStore.markRead(uri, read: !uri.isRead)
            }
            Button(uri.isReadLater ? "Remove from Read Later" : "Read Later") {
                UriStore.markReadLater(uri, readLater: !uri.isReadLater)
            }
            Divider()
            Button("Upvote") { UriStore.vote(uri, vote: 1) }
            Button("Downvote") { UriStore.vote(uri, vote: -1) }
            if uri.vote != nil {
                Button("Remove Vote") { UriStore.vote(uri, vote: nil) }
            }
            Divider()
            Button("Edit Note") { showNoteSheet = true }
            Button("Refresh Metadata") {
                Task { await UrlMetadataService.fetchAndApply(to: uri) }
            }
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(uri.url, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) { showDeleteConfirm = true }
        }
        .sheet(isPresented: $showNoteSheet) {
            UriNoteView(uri: uri)
        }
        .confirmationDialog("Delete \"\(uri.displayTitle)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                UriStore.delete(in: modelContext, uri: uri)
            }
        }
    }
}
