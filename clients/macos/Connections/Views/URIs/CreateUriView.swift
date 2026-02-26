import SwiftUI

struct CreateUriView: View {
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var isLoading = false
    @State private var metadata: UriMetadataResponse?
    @State private var matchingConnections: [Connection] = []
    @State private var error: String?

    var body: some View {
        if let metadata {
            UriPreviewForm(
                url: url,
                metadata: metadata,
                matchingConnections: matchingConnections,
                onCreated: {
                    onCreated()
                    dismiss()
                }
            )
        } else {
            VStack(spacing: 16) {
                Text("Create URI")
                    .font(.headline)

                TextField("URL", text: $url, prompt: Text("https://example.com/article"))
                    .textFieldStyle(.roundedBorder)

                Text("Paste a URL to save it. Metadata will be fetched automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }

                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Fetch") { fetchMetadata() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(url.isEmpty || isLoading)
                }

                if isLoading { ProgressView() }
            }
            .padding()
            .frame(width: 450)
        }
    }

    private func fetchMetadata() {
        isLoading = true
        error = nil
        Task {
            do {
                guard let parsed = URL(string: url), let host = parsed.host else {
                    await MainActor.run {
                        error = "Invalid URL"
                        isLoading = false
                    }
                    return
                }

                async let metadataResult = MetadataService.fetchUriMetadata(url: url)
                async let connectionsResult = ConnectionService.findByHost(host)

                let (meta, connections) = try await (metadataResult, connectionsResult)
                await MainActor.run {
                    metadata = meta
                    matchingConnections = connections
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct UriPreviewForm: View {
    let url: String
    let metadata: UriMetadataResponse
    let matchingConnections: [Connection]
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var selectedKind: UriKind
    @State private var selectedConnectionId: Int?
    @State private var isCreating = false
    @State private var error: String?

    init(url: String, metadata: UriMetadataResponse, matchingConnections: [Connection], onCreated: @escaping () -> Void) {
        self.url = url
        self.metadata = metadata
        self.matchingConnections = matchingConnections
        self.onCreated = onCreated
        self._title = State(initialValue: metadata.title ?? "")

        // Infer kind from content type
        var kind: UriKind = .unknown
        if let contentType = metadata.contentType?.lowercased() {
            if contentType.contains("video") { kind = .video }
            else if contentType.contains("article") || contentType.contains("blog") { kind = .blog }
        }
        self._selectedKind = State(initialValue: kind)
        self._selectedConnectionId = State(initialValue: matchingConnections.first?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create URI")
                .font(.headline)

            LabeledContent("URL") { Text(url).font(.caption).lineLimit(1) }

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("Kind", selection: $selectedKind) {
                ForEach(UriKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }

            Picker("Connection", selection: $selectedConnectionId) {
                Text("None (Inbox)").tag(nil as Int?)
                if !matchingConnections.isEmpty {
                    Section("Matching") {
                        ForEach(matchingConnections) { conn in
                            Text(conn.name).tag(conn.id as Int?)
                        }
                    }
                }
            }

            if let siteName = metadata.siteName {
                LabeledContent("Site") { Text(siteName).font(.caption) }
            }
            if let author = metadata.authorName {
                LabeledContent("Author") { Text(author).font(.caption) }
            }
            if let desc = metadata.description {
                LabeledContent("Description") { Text(desc).font(.caption).lineLimit(3) }
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { createUri() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isCreating)
            }

            if isCreating { ProgressView() }
        }
        .padding()
        .frame(width: 500)
    }

    private func createUri() {
        isCreating = true
        error = nil
        Task {
            do {
                let request = CreateUriRequest(
                    url: url,
                    connectionId: selectedConnectionId,
                    kind: selectedKind,
                    title: title.trimmingCharacters(in: .whitespaces).isEmpty ? nil : title.trimmingCharacters(in: .whitespaces)
                )
                _ = try await UriService.create(request)
                await MainActor.run {
                    isCreating = false
                    onCreated()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}
