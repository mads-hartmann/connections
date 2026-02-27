import SwiftUI

struct ConnectionRowView: View {
    let connection: Connection
    let onRefresh: () -> Void

    @State private var showEditSheet = false
    @State private var showNoteSheet = false
    @State private var showMetadataSheet = false
    @State private var showRefreshSheet = false
    @State private var showDeleteConfirm = false
    @State private var showUris = false
    @State private var showFeeds = false

    var body: some View {
        NavigationLink(value: connection) {
            HStack(spacing: 10) {
                if let photo = connection.photo, let url = URL(string: photo) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.name)
                        .fontWeight(.medium)
                    if !connection.tags.isEmpty {
                        Text(connection.tags.map(\.name).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if connection.unreadUriCount > 0 {
                    Text("\(connection.unreadUriCount)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 2)
        }
        .contextMenu {
            Button("View URIs") { showUris = true }
            Button("View Feeds") { showFeeds = true }
            Divider()
            Button("Mark All as Read") { markAllRead() }
            Divider()
            Button("Add Metadata") { showMetadataSheet = true }
            Button("Edit") { showEditSheet = true }
            Button("Edit Note") { showNoteSheet = true }
            Button("Refresh from Website") { showRefreshSheet = true }
            Divider()
            Button("Delete", role: .destructive) { showDeleteConfirm = true }
        }
        .navigationDestination(isPresented: $showUris) {
            ConnectionUriListView(connection: connection)
        }
        .navigationDestination(isPresented: $showFeeds) {
            FeedListView(connectionId: connection.id, connectionName: connection.name)
        }
        .sheet(isPresented: $showEditSheet) {
            ConnectionEditView(connection: connection, onSaved: onRefresh)
        }
        .sheet(isPresented: $showNoteSheet) {
            ConnectionNoteView(connectionId: connection.id, currentNote: connection.note, onSaved: onRefresh)
        }
        .sheet(isPresented: $showMetadataSheet) {
            AddMetadataView(connectionId: connection.id, connectionName: connection.name, onSaved: onRefresh)
        }
        .sheet(isPresented: $showRefreshSheet) {
            ConnectionRefreshMetadataView(connection: connection, onSaved: onRefresh)
        }
        .confirmationDialog("Delete \"\(connection.name)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteConnection() }
        }
    }

    private func markAllRead() {
        Task {
            _ = try? await UriService.markAllReadByConnection(connectionId: connection.id)
            await MainActor.run { onRefresh() }
        }
    }

    private func deleteConnection() {
        Task {
            try? await ConnectionService.delete(id: connection.id)
            await MainActor.run { onRefresh() }
        }
    }
}
