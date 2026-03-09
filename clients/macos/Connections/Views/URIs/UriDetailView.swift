import SwiftUI

struct UriDetailView: View {
    let uri: CDUri

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HSplitView {
            // Content pane — WKWebView
            if let url = URL(string: uri.url) {
                WebContentView(url: url)
                    .frame(minWidth: 400)
            } else {
                Text("Invalid URL")
                    .frame(minWidth: 400)
            }

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
                            Button(uri.isRead ? "Mark Unread" : "Mark Read") {
                                UriStore.markRead(uri, read: !uri.isRead)
                            }
                            .buttonStyle(.bordered)
                            Button(uri.isReadLater ? "Remove Later" : "Read Later") {
                                UriStore.markReadLater(uri, readLater: !uri.isReadLater)
                            }
                            .buttonStyle(.bordered)
                        }

                        HStack(spacing: 8) {
                            Button { UriStore.vote(uri, vote: 1) } label: {
                                Image(systemName: "arrow.up")
                                    .foregroundStyle(uri.isUpvoted ? .green : .primary)
                            }
                            .buttonStyle(.bordered)

                            Button { UriStore.vote(uri, vote: -1) } label: {
                                Image(systemName: "arrow.down")
                                    .foregroundStyle(uri.isDownvoted ? .red : .primary)
                            }
                            .buttonStyle(.bordered)

                            if uri.vote != nil {
                                Button("Clear") { UriStore.vote(uri, vote: nil) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }

                    Divider()

                    Group {
                        if let author = uri.author {
                            LabeledContent("Author", value: author)
                        }
                        if let name = uri.connectionName {
                            LabeledContent("Connection", value: name)
                        }
                        LabeledContent("Kind", value: uri.kind.displayName)
                        LabeledContent("Published", value: DateFormatting.formatDate(uri.publishedAt))
                        LabeledContent("Read", value: uri.isRead ? DateFormatting.formatDate(uri.readAt) : "Unread")

                        if let siteName = uri.ogSiteName {
                            LabeledContent("Site", value: siteName)
                        }
                    }
                    .font(.caption)

                    if !uri.tags.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tags").font(.headline)
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

                    if let note = uri.note, !note.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note").font(.headline)
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL").font(.headline)
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
        .toolbar(id: "uriDetail") {
            ToolbarItem(id: "copyUrl", placement: .secondaryAction) {
                Button("Copy URL", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(uri.url, forType: .string)
                }
            }
        }
    }

    private func openInBrowser() {
        if let url = URL(string: uri.url) { NSWorkspace.shared.open(url) }
    }
}
