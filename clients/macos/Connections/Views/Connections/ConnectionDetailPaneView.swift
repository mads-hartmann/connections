import SwiftUI
import SwiftData

struct ConnectionDetailPaneView: View {
    let connection: CDConnection

    @Environment(\.modelContext) private var modelContext
    @State private var showUnreadOnly = false
    @State private var showEditSheet = false
    @State private var showNoteSheet = false
    @State private var showMetadataSheet = false
    @State private var showRefreshSheet = false
    @State private var showDeleteConfirm = false
    @State private var showFeedsSheet = false
    @State private var showCreateUriSheet = false

    private var uris: [CDUri] {
        UriStore.listByConnection(connection, unreadOnly: showUnreadOnly)
    }

    var body: some View {
        VStack(spacing: 0) {
            connectionHeader.padding()
            Divider()
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
                    Button("Edit Connection", systemImage: "pencil") { showEditSheet = true }
                    Button("Edit Note", systemImage: "note.text") { showNoteSheet = true }
                    Button("Add Metadata", systemImage: "info.circle") { showMetadataSheet = true }
                    Button("View Feeds", systemImage: "list.bullet") { showFeedsSheet = true }
                    Divider()
                    Button("Refresh from Website", systemImage: "arrow.clockwise") { showRefreshSheet = true }
                    Button("Mark All as Read", systemImage: "checkmark.circle") {
                        _ = UriStore.markAllReadByConnection(connection)
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
        .sheet(isPresented: $showEditSheet) {
            ConnectionEditView(connection: connection)
        }
        .sheet(isPresented: $showNoteSheet) {
            ConnectionNoteView(connection: connection)
        }
        .sheet(isPresented: $showMetadataSheet) {
            AddMetadataView(connection: connection)
        }
        .sheet(isPresented: $showRefreshSheet) {
            ConnectionRefreshMetadataView(connection: connection)
        }
        .sheet(isPresented: $showFeedsSheet) {
            NavigationStack {
                FeedListView(connection: connection)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showFeedsSheet = false }
                        }
                    }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showCreateUriSheet) {
            CreateUriView()
        }
        .confirmationDialog("Delete \"\(connection.name)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                ConnectionStore.delete(in: modelContext, connection: connection)
            }
        }
    }

    // MARK: - Connection Header

    private var connectionHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            if let photo = connection.photo, let url = URL(string: photo) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill").font(.system(size: 48)).foregroundStyle(.secondary)
                }
                .frame(width: 64, height: 64).clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48)).foregroundStyle(.secondary)
                    .frame(width: 64, height: 64)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(connection.name).font(.title2).fontWeight(.semibold)

                HStack(spacing: 12) {
                    Label("\(connection.feedCount) feeds", systemImage: "list.bullet")
                    Label("\(connection.uriCount) URIs", systemImage: "doc.text")
                    if connection.unreadUriCount > 0 {
                        Label("\(connection.unreadUriCount) unread", systemImage: "circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)

                if !connection.tags.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(connection.tags) { tag in
                            Text(tag.name)
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                if !connection.metadata.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(connection.metadata) { meta in
                            if meta.value.hasPrefix("http"), let url = URL(string: meta.value) {
                                Link(destination: url) {
                                    Text(meta.fieldType.name)
                                        .font(.caption2).foregroundStyle(.blue)
                                }
                            } else {
                                Text("\(meta.fieldType.name): \(meta.value)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let note = connection.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }

            Spacer()
        }
    }

    // MARK: - URI Table

    private var uriTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("URIs").font(.headline)
                Spacer()
                Picker("Filter", selection: $showUnreadOnly) {
                    Text("All").tag(false)
                    Text("Unread").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            .padding(.horizontal).padding(.vertical, 8)

            Divider()

            if uris.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No URIs", systemImage: "doc.text",
                    description: Text(showUnreadOnly ? "No unread URIs" : "No URIs for this connection")
                )
                Spacer()
            } else {
                Table(uris) {
                    TableColumn("") { uri in
                        Circle().fill(uri.isRead ? .clear : .blue).frame(width: 8, height: 8)
                    }.width(16)

                    TableColumn("Title") { uri in
                        Text(uri.displayTitle)
                            .fontWeight(uri.isRead ? .regular : .medium)
                            .lineLimit(1).help(uri.url)
                    }

                    TableColumn("Kind") { uri in
                        Text(uri.kind.displayName).font(.caption).foregroundStyle(.secondary)
                    }.width(60)

                    TableColumn("Published") { uri in
                        Text(DateFormatting.formatDate(uri.publishedAt))
                            .font(.caption).foregroundStyle(.secondary)
                    }.width(100)

                    TableColumn("") { uri in
                        HStack(spacing: 4) {
                            if uri.isReadLater {
                                Image(systemName: "clock").font(.caption2).foregroundStyle(.orange)
                            }
                            if uri.isUpvoted {
                                Image(systemName: "arrow.up").font(.caption2).foregroundStyle(.green)
                            }
                            if uri.isDownvoted {
                                Image(systemName: "arrow.down").font(.caption2).foregroundStyle(.red)
                            }
                        }
                    }.width(50)
                }
                .contextMenu(forSelectionType: CDUri.ID.self) { _ in } primaryAction: { ids in
                    if let id = ids.first, let uri = uris.first(where: { $0.id == id }) {
                        if let url = URL(string: uri.url) { NSWorkspace.shared.open(url) }
                    }
                }
            }
        }
    }
}
