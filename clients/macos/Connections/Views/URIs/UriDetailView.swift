import SwiftUI

struct UriDetailView: View {
    let uri: UriEntry
    let onRefresh: () -> Void

    @State private var content: String?
    @State private var contentError: String?
    @State private var isLoadingContent = true

    var body: some View {
        HSplitView {
            // Content pane
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(uri.displayTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .textSelection(.enabled)

                    if let imageUrl = uri.ogImage ?? uri.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.gray.opacity(0.1)
                        }
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if isLoadingContent {
                        ProgressView("Loading content...")
                    } else if let error = contentError {
                        Text("⚠️ \(error)")
                            .foregroundStyle(.orange)
                        if let fallback = uri.ogDescription ?? uri.content {
                            Divider()
                            Text(fallback)
                                .textSelection(.enabled)
                        }
                    } else if let content {
                        Text(content)
                            .textSelection(.enabled)
                    } else {
                        Text("No content available")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .frame(minWidth: 400)

            // Metadata sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Actions
                    VStack(spacing: 8) {
                        Button(action: { openInBrowser() }) {
                            Label("Open in Browser", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        HStack(spacing: 8) {
                            Button(uri.isRead ? "Mark Unread" : "Mark Read") { toggleRead() }
                                .buttonStyle(.bordered)
                            Button(uri.isReadLater ? "Remove Later" : "Read Later") { toggleReadLater() }
                                .buttonStyle(.bordered)
                        }

                        HStack(spacing: 8) {
                            Button(action: { vote(1) }) {
                                Image(systemName: "arrow.up")
                                    .foregroundStyle(uri.isUpvoted ? .green : .primary)
                            }
                            .buttonStyle(.bordered)

                            Button(action: { vote(-1) }) {
                                Image(systemName: "arrow.down")
                                    .foregroundStyle(uri.isDownvoted ? .red : .primary)
                            }
                            .buttonStyle(.bordered)

                            if uri.vote != nil {
                                Button("Clear") { vote(nil) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }

                    Divider()

                    // Info
                    Group {
                        if let author = uri.author {
                            LabeledContent("Author", value: author)
                        }
                        if let name = uri.connectionName {
                            LabeledContent("Connection", value: name)
                        }
                        LabeledContent("Kind", value: uri.kind.displayName)
                        LabeledContent("Published", value: DateFormatting.format(uri.publishedAt))
                        LabeledContent("Read", value: uri.isRead ? DateFormatting.format(uri.readAt) : "Unread")

                        if let siteName = uri.ogSiteName {
                            LabeledContent("Site", value: siteName)
                        }
                    }
                    .font(.caption)

                    // Tags
                    if !uri.tags.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tags")
                                .font(.headline)
                            FlowLayout(spacing: 4) {
                                ForEach(uri.tags) { tag in
                                    Text(tag.name)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Note
                    if let note = uri.note, !note.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note")
                                .font(.headline)
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // URL
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL")
                            .font(.headline)
                        Text(uri.url)
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }
            .frame(width: 280)
        }
        .navigationTitle(uri.displayTitle)
        .toolbar {
            ToolbarItem {
                Button("Copy URL", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(uri.url, forType: .string)
                }
            }
        }
        .task { await loadContent() }
    }

    private func loadContent() async {
        do {
            let result = try await UriService.fetchContent(id: uri.id)
            await MainActor.run {
                content = result.markdown
                isLoadingContent = false
            }
        } catch {
            await MainActor.run {
                contentError = error.localizedDescription
                isLoadingContent = false
            }
        }
    }

    private func openInBrowser() {
        if let url = URL(string: uri.url) {
            NSWorkspace.shared.open(url)
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
}
