import SwiftUI
import UniformTypeIdentifiers

struct ImportOpmlView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var preview: ImportPreview?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showFilePicker = false

    @State private var selectedConnections: Set<String> = []
    @State private var isImporting = false
    @State private var importResult: ImportResult?

    var body: some View {
        VStack(spacing: 16) {
            if let importResult {
                importResultView(importResult)
            } else if let preview {
                importPreviewView(preview)
            } else {
                filePickerView
            }
        }
        .padding()
        .frame(minWidth: 550, minHeight: 400)
    }

    // MARK: - File Picker

    private var filePickerView: some View {
        VStack(spacing: 16) {
            Text("Import OPML").font(.headline)

            Text("Select an OPML file exported from your RSS reader.")
                .font(.caption).foregroundStyle(.secondary)

            Button("Choose File...") { showFilePicker = true }
                .buttonStyle(.borderedProminent)

            if isLoading { ProgressView("Parsing OPML...") }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "opml") ?? .xml, .xml],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    // MARK: - Preview

    private func importPreviewView(_ preview: ImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Import Preview").font(.headline)
                Spacer()
                Text("\(selectedConnections.count) of \(preview.connections.count) selected")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(preview.connections) { connection in
                        HStack {
                            Toggle(isOn: connectionBinding(connection.name)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(connection.name).fontWeight(.medium)
                                    HStack(spacing: 8) {
                                        Text("\(connection.feeds.count) feed\(connection.feeds.count != 1 ? "s" : "")")
                                            .font(.caption).foregroundStyle(.secondary)
                                        if !connection.tags.isEmpty {
                                            Text(connection.tags.joined(separator: ", "))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !preview.errors.isEmpty {
                        Divider()
                        Text("Failed Feeds (\(preview.errors.count))")
                            .font(.subheadline).foregroundStyle(.red)
                        ForEach(preview.errors, id: \.url) { error in
                            HStack {
                                Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                                VStack(alignment: .leading) {
                                    Text(error.url).font(.caption)
                                    Text(error.error).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Select All") {
                    selectedConnections = Set(preview.connections.map(\.name))
                }
                Button("Deselect All") {
                    selectedConnections = []
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Import \(selectedConnections.count)") { confirmImport(preview) }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedConnections.isEmpty || isImporting)
            }

            if isImporting { ProgressView() }
        }
    }

    // MARK: - Result

    private func importResultView(_ result: ImportResult) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle).foregroundStyle(.green)

            Text("Import Complete").font(.headline)

            VStack(spacing: 4) {
                Text("\(result.createdConnections) connections created")
                Text("\(result.createdFeeds) feeds created")
                Text("\(result.createdTags) tags created")
            }
            .font(.body).foregroundStyle(.secondary)

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Actions

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isLoading = true
            error = nil
            Task {
                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot access file"])
                    }
                    defer { url.stopAccessingSecurityScopedResource() }

                    let content = try String(contentsOf: url, encoding: .utf8)
                    let result = await OpmlImportService.preview(opmlContent: content)

                    await MainActor.run {
                        switch result {
                        case .success(let previewData):
                            preview = previewData
                            selectedConnections = Set(previewData.connections.map(\.name))
                        case .failure(let err):
                            error = err.message
                        }
                        isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.error = error.localizedDescription
                        isLoading = false
                    }
                }
            }
        case .failure(let error):
            self.error = error.localizedDescription
        }
    }

    private func confirmImport(_ preview: ImportPreview) {
        isImporting = true
        let connectionsToImport = preview.connections.filter { selectedConnections.contains($0.name) }

        let result = OpmlImportService.confirm(
            connections: connectionsToImport,
            context: modelContext
        )

        importResult = result
        isImporting = false
    }

    private func connectionBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { selectedConnections.contains(name) },
            set: { isOn in
                if isOn { selectedConnections.insert(name) }
                else { selectedConnections.remove(name) }
            }
        )
    }
}
