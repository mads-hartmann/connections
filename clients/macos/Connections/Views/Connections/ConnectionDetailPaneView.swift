import SwiftUI

struct ConnectionDetailPaneView: View {
    let connection: Connection

    @State private var uris: [UriEntry] = []
    @State private var isLoadingUris = false
    @State private var page = 1
    @State private var hasMore = false
    @State private var showUnreadOnly = false

    @State private var showEditSheet = false
    @State private var showNoteSheet = false
    @State private var showMetadataSheet = false
    @State private var showRefreshSheet = false
    @State private var showDeleteConfirm = false
    @State private var showFeedsSheet = false
    @State private var showCreateUriSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Connection detail header
            connectionHeader
                .padding()

            Divider()

            // URI table
            uriTable
        }
        .navigationTitle(connection.name)
        .toolbar(id: "connectionDetail") {
            ToolbarItem(id: "createUri", placement: .primaryAction) {
                Button("Create URI", systemImage: "plus") {
                    showCreateUriSheet = true
                }
            }
            ToolbarItem(id: "connectionMenu", placement: .primaryAction) {
                Menu {
                    Button("Edit Connection", systemImage: "pencil") {
                        showEditSheet = true
                    }
                    Button("Edit Note", systemImage: "note.text") {
                        showNoteSheet = true
                    }
                    Button("Add Metadata", systemImage: "info.circle") {
                        showMetadataSheet = true
                    }
                    Button("View Feeds", systemImage: "list.bullet") {
                        showFeedsSheet = true
                    }
                    Divider()
                    Button("Refresh from Website", systemImage: "arrow.clockwise") {
                        showRefreshSheet = true
                    }
                    Button("Mark All as Read", systemImage: "checkmark.circle") {
                        markAllRead()
                    }
                    Divider()
                    Button("Delete Connection", systemImage: "trash", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { loadUris() }
        .onChange(of: connection.id) { _, _ in
            uris = []
            page = 1
            showUnreadOnly = false
            loadUris()
        }
        .sheet(isPresented: $showEditSheet) {
            ConnectionEditView(connection: connection, onSaved: { loadUris() })
        }
        .sheet(isPresented: $showNoteSheet) {
            ConnectionNoteView(connectionId: connection.id, currentNote: connection.note, onSaved: {})
        }
        .sheet(isPresented: $showMetadataSheet) {
            AddMetadataView(connectionId: connection.id, connectionName: connection.name, onSaved: {})
        }
        .sheet(isPresented: $showRefreshSheet) {
            ConnectionRefreshMetadataView(connection: connection, onSaved: {})
        }
        .sheet(isPresented: $showFeedsSheet) {
            NavigationStack {
                FeedListView(connectionId: connection.id, connectionName: connection.name)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showFeedsSheet = false }
                        }
                    }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showCreateUriSheet) {
            CreateUriView(onCreated: { loadUris() })
        }
        .confirmationDialog("Delete \"\(connection.name)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteConnection() }
        }
    }

    // MARK: - Connection Header

    private var connectionHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            // Photo
            if let photo = connection.photo, let url = URL(string: photo) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .frame(width: 64, height: 64)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(connection.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                // Stats row
                HStack(spacing: 12) {
                    Label("\(connection.feedCount) feeds", systemImage: "list.bullet")
                    Label("\(connection.uriCount) URIs", systemImage: "doc.text")
                    if connection.unreadUriCount > 0 {
                        Label("\(connection.unreadUriCount) unread", systemImage: "circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Tags
                if !connection.tags.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(connection.tags) { tag in
                            Text(tag.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Metadata links
                if !connection.metadata.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(connection.metadata) { meta in
                            if meta.value.hasPrefix("http"), let url = URL(string: meta.value) {
                                Link(destination: url) {
                                    Text(meta.fieldType.name)
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            } else {
                                Text("\(meta.fieldType.name): \(meta.value)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Note preview
                if let note = connection.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
    }

    // MARK: - URI Table

    private var uriTable: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack {
                Text("URIs")
                    .font(.headline)

                Spacer()

                Picker("Filter", selection: $showUnreadOnly) {
                    Text("All").tag(false)
                    Text("Unread").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .onChange(of: showUnreadOnly) { _, _ in loadUris() }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Table
            if isLoadingUris && uris.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if uris.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No URIs",
                    systemImage: "doc.text",
                    description: Text(showUnreadOnly ? "No unread URIs" : "No URIs for this connection")
                )
                Spacer()
            } else {
                Table(uris) {
                    TableColumn("") { uri in
                        Circle()
                            .fill(uri.isRead ? .clear : .blue)
                            .frame(width: 8, height: 8)
                    }
                    .width(16)

                    TableColumn("Title") { uri in
                        Text(uri.displayTitle)
                            .fontWeight(uri.isRead ? .regular : .medium)
                            .lineLimit(1)
                            .help(uri.url)
                    }

                    TableColumn("Kind") { uri in
                        Text(uri.kind.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(60)

                    TableColumn("Published") { uri in
                        Text(DateFormatting.format(uri.publishedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(100)

                    TableColumn("") { uri in
                        HStack(spacing: 4) {
                            if uri.isReadLater {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            if uri.isUpvoted {
                                Image(systemName: "arrow.up")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                            if uri.isDownvoted {
                                Image(systemName: "arrow.down")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .width(50)
                }
                .contextMenu(forSelectionType: UriEntry.ID.self) { _ in } primaryAction: { ids in
                    if let id = ids.first, let uri = uris.first(where: { $0.id == id }) {
                        if let url = URL(string: uri.url) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }

                if hasMore {
                    Button("Load More") { loadMore() }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadUris() {
        page = 1
        isLoadingUris = true
        Task {
            do {
                let response = try await UriService.listByConnection(
                    connectionId: connection.id, page: 1, unread: showUnreadOnly
                )
                await MainActor.run {
                    uris = response.data
                    hasMore = response.page < response.totalPages
                    isLoadingUris = false
                }
            } catch {
                await MainActor.run { isLoadingUris = false }
            }
        }
    }

    private func loadMore() {
        page += 1
        Task {
            do {
                let response = try await UriService.listByConnection(
                    connectionId: connection.id, page: page, unread: showUnreadOnly
                )
                await MainActor.run {
                    uris.append(contentsOf: response.data)
                    hasMore = response.page < response.totalPages
                }
            } catch {
                await MainActor.run { page -= 1 }
            }
        }
    }

    private func markAllRead() {
        Task {
            _ = try? await UriService.markAllReadByConnection(connectionId: connection.id)
            await MainActor.run { loadUris() }
        }
    }

    private func deleteConnection() {
        Task {
            try? await ConnectionService.delete(id: connection.id)
        }
    }
}
