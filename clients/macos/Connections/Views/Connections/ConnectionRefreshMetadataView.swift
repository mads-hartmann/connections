import SwiftUI

struct ConnectionRefreshMetadataView: View {
    let connection: Connection
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var preview: RefreshMetadataPreview?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var error: String?

    // Selections
    @State private var updateName = true
    @State private var updatePhoto = true
    @State private var selectedFeeds: Set<String> = []
    @State private var selectedProfiles: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Refresh Metadata: \(connection.name)")
                .font(.headline)

            if isLoading {
                ProgressView("Fetching metadata...")
                    .frame(maxWidth: .infinity)
            } else if let error {
                Text(error).foregroundStyle(.red)
            } else if let preview {
                previewContent(preview)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if preview != nil {
                    Button("Apply") { applyChanges() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(isSubmitting)
                }
            }

            if isSubmitting { ProgressView() }
        }
        .padding()
        .frame(width: 500, minHeight: 300)
        .task { await loadPreview() }
    }

    @ViewBuilder
    private func previewContent(_ preview: RefreshMetadataPreview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Source") { Text(preview.sourceUrl).font(.caption) }

                if let proposedName = preview.proposedName, proposedName != preview.currentName {
                    Toggle(isOn: $updateName) {
                        Text("Update name: \"\(preview.currentName)\" → \"\(proposedName)\"")
                            .font(.caption)
                    }
                }

                if let proposedPhoto = preview.proposedPhoto, proposedPhoto != preview.currentPhoto {
                    Toggle(isOn: $updatePhoto) {
                        Text(preview.currentPhoto != nil ? "Update photo" : "Add photo")
                            .font(.caption)
                    }
                }

                if !preview.proposedFeeds.isEmpty {
                    Divider()
                    Text("Discovered Feeds").font(.subheadline).fontWeight(.medium)
                    ForEach(preview.proposedFeeds, id: \.url) { feed in
                        Toggle(isOn: binding(for: feed.url, in: $selectedFeeds)) {
                            VStack(alignment: .leading) {
                                Text(feed.title ?? "Untitled").font(.caption)
                                Text("\(feed.url) (\(feed.format))").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                let existingUrls = Set(preview.currentMetadata.map(\.value))
                let newProfiles = preview.proposedProfiles.filter { !existingUrls.contains($0.url) }

                if !newProfiles.isEmpty {
                    Divider()
                    Text("Discovered Profiles").font(.subheadline).fontWeight(.medium)
                    ForEach(newProfiles, id: \.url) { profile in
                        Toggle(isOn: binding(for: profile.url, in: $selectedProfiles)) {
                            Text("\(profile.fieldType.name): \(profile.url)")
                                .font(.caption)
                        }
                    }
                }

                if preview.proposedName == nil && preview.proposedPhoto == nil
                    && preview.proposedFeeds.isEmpty && newProfiles.isEmpty {
                    Text("No new metadata discovered.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func loadPreview() async {
        do {
            let result = try await ConnectionService.fetchRefreshPreview(connectionId: connection.id)
            await MainActor.run {
                preview = result
                selectedFeeds = Set(result.proposedFeeds.map(\.url))
                let existingUrls = Set(result.currentMetadata.map(\.value))
                selectedProfiles = Set(result.proposedProfiles.filter { !existingUrls.contains($0.url) }.map(\.url))
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func applyChanges() {
        guard let preview else { return }
        isSubmitting = true

        Task {
            // Update name/photo
            if updateName, let proposedName = preview.proposedName, proposedName != preview.currentName {
                let photo = updatePhoto ? preview.proposedPhoto : connection.photo
                _ = try? await ConnectionService.update(id: connection.id, name: proposedName, photo: photo)
            } else if updatePhoto, let proposedPhoto = preview.proposedPhoto, proposedPhoto != preview.currentPhoto {
                _ = try? await ConnectionService.update(id: connection.id, name: connection.name, photo: proposedPhoto)
            }

            // Add feeds
            for feed in preview.proposedFeeds where selectedFeeds.contains(feed.url) {
                _ = try? await FeedService.create(connectionId: connection.id, url: feed.url, title: feed.title ?? "")
            }

            // Add profiles
            let existingUrls = Set(preview.currentMetadata.map(\.value))
            for profile in preview.proposedProfiles where selectedProfiles.contains(profile.url) && !existingUrls.contains(profile.url) {
                _ = try? await ConnectionService.createMetadata(
                    connectionId: connection.id,
                    fieldTypeId: profile.fieldType.id,
                    value: profile.url
                )
            }

            await MainActor.run {
                isSubmitting = false
                onSaved()
                dismiss()
            }
        }
    }

    private func binding(for url: String, in set: Binding<Set<String>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(url) },
            set: { isOn in
                if isOn { set.wrappedValue.insert(url) }
                else { set.wrappedValue.remove(url) }
            }
        )
    }
}
