import SwiftUI
import SwiftData
import LinkPresentation

struct CreateUriView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var url = ""
    @State private var isLoading = false
    @State private var metadata: LPLinkMetadata?
    @State private var matchingConnections: [CDConnection] = []
    @State private var error: String?

    // Form state after metadata fetch
    @State private var title = ""
    @State private var selectedKind: CDUriKind = .unknown
    @State private var selectedConnection: CDConnection?
    @State private var isCreating = false

    var body: some View {
        if metadata != nil {
            previewForm
        } else {
            urlInputForm
        }
    }

    private var urlInputForm: some View {
        VStack(spacing: 16) {
            Text("Create URI").font(.headline)

            TextField("URL", text: $url, prompt: Text("https://example.com/article"))
                .textFieldStyle(.roundedBorder)

            Text("Paste a URL to save it. Metadata will be fetched automatically.")
                .font(.caption).foregroundStyle(.secondary)

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
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

    private var previewForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create URI").font(.headline)

            LabeledContent("URL") { Text(url).font(.caption).lineLimit(1) }

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("Kind", selection: $selectedKind) {
                ForEach(CDUriKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }

            Picker("Connection", selection: $selectedConnection) {
                Text("None (Inbox)").tag(nil as CDConnection?)
                if !matchingConnections.isEmpty {
                    Section("Matching") {
                        ForEach(matchingConnections) { conn in
                            Text(conn.name).tag(conn as CDConnection?)
                        }
                    }
                }
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
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

    private func fetchMetadata() {
        isLoading = true
        error = nil
        Task {
            guard let parsed = URL(string: url), let host = parsed.host else {
                await MainActor.run { error = "Invalid URL"; isLoading = false }
                return
            }

            let provider = LPMetadataProvider()
            do {
                let meta = try await provider.startFetchingMetadata(for: parsed)
                let connections = ConnectionStore.findByHost(in: modelContext, host: host)

                await MainActor.run {
                    metadata = meta
                    title = meta.title ?? ""
                    matchingConnections = connections
                    selectedConnection = connections.first
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

    private func createUri() {
        isCreating = true
        let uri = UriStore.create(
            in: modelContext,
            url: url,
            kind: selectedKind,
            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? nil : title.trimmingCharacters(in: .whitespaces),
            connection: selectedConnection
        )

        // Apply metadata
        if let meta = metadata {
            uri.ogTitle = meta.title
            uri.ogFetchedAt = Date()
        }

        try? modelContext.save()
        dismiss()
    }
}
