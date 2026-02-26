import SwiftUI

struct UriRowView: View {
    let uri: UriEntry
    let onRefresh: () -> Void

    @State private var showDetail = false
    @State private var showEditSheet = false
    @State private var showNoteSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationLink(value: uri) {
            HStack(spacing: 8) {
                // Read status indicator
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
                            Text(DateFormatting.format(date))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    if uri.isReadLater {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if uri.isUpvoted {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if uri.isDownvoted {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if !uri.tags.isEmpty {
                        Image(systemName: "tag")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .contextMenu {
            Button("Open in Browser") {
                if let url = URL(string: uri.url) {
                    NSWorkspace.shared.open(url)
                }
            }
            Divider()
            Button(uri.isRead ? "Mark as Unread" : "Mark as Read") { toggleRead() }
            Button(uri.isReadLater ? "Remove from Read Later" : "Read Later") { toggleReadLater() }
            Divider()
            Button("Upvote") { vote(1) }
            Button("Downvote") { vote(-1) }
            if uri.vote != nil {
                Button("Remove Vote") { vote(nil) }
            }
            Divider()
            Button("Edit") { showEditSheet = true }
            Button("Edit Note") { showNoteSheet = true }
            Button("Refresh Metadata") { refreshMetadata() }
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(uri.url, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) { showDeleteConfirm = true }
        }
        .navigationDestination(isPresented: $showDetail) {
            UriDetailView(uri: uri, onRefresh: onRefresh)
        }
        .sheet(isPresented: $showEditSheet) {
            UriEditView(uri: uri, onSaved: onRefresh)
        }
        .sheet(isPresented: $showNoteSheet) {
            UriNoteView(uriId: uri.id, currentNote: uri.note, onSaved: onRefresh)
        }
        .confirmationDialog("Delete \"\(uri.displayTitle)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteUri() }
        }
    }

    private func toggleRead() {
        Task {
            _ = try? await UriService.markRead(id: uri.id, read: !uri.isRead)
            await MainActor.run { onRefresh() }
        }
    }

    private func toggleReadLater() {
        Task {
            _ = try? await UriService.markReadLater(id: uri.id, readLater: !uri.isReadLater)
            await MainActor.run { onRefresh() }
        }
    }

    private func vote(_ value: Int?) {
        Task {
            _ = try? await UriService.vote(id: uri.id, vote: value)
            await MainActor.run { onRefresh() }
        }
    }

    private func refreshMetadata() {
        Task {
            _ = try? await UriService.refreshMetadata(id: uri.id)
            await MainActor.run { onRefresh() }
        }
    }

    private func deleteUri() {
        Task {
            try? await UriService.delete(id: uri.id)
            await MainActor.run { onRefresh() }
        }
    }
}
