import SwiftUI
import SwiftData

struct ConnectionRefreshMetadataView: View {
    let connection: CDConnection

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var discoveredMetadata: DiscoveredContactMetadata?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var error: String?

    @State private var updateName = true
    @State private var updatePhoto = true
    @State private var selectedFeeds: Set<String> = []
    @State private var selectedProfiles: Set<String> = []

    // Source URL: use the first website metadata, or first feed URL's host
    private var sourceUrl: String {
        if let website = connection.metadata.first(where: { $0.fieldType == .website }) {
            return website.value
        }
        if let feed = connection.feeds.first, let host = URL(string: feed.url)?.host {
            return "https://\(host)"
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Refresh Metadata: \(connection.name)").font(.headline)

            if isLoading {
                ProgressView("Fetching metadata...").frame(maxWidth: .infinity)
            } else if let error {
                Text(error).foregroundStyle(.red)
            } else if let metadata = discoveredMetadata {
                previewContent(metadata)
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                if discoveredMetadata != nil {
                    Button("Apply") { applyChanges() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(isSubmitting)
                }
            }

            if isSubmitting { ProgressView() }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 300)
        .task { await loadPreview() }
    }

    @ViewBuilder
    private func previewContent(_ metadata: DiscoveredContactMetadata) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Source") { Text(sourceUrl).font(.caption) }

                if let proposedName = metadata.name, proposedName != connection.name {
                    Toggle(isOn: $updateName) {
                        Text("Update name: \"\(connection.name)\" → \"\(proposedName)\"").font(.caption)
                    }
                }

                if let proposedPhoto = metadata.photo, proposedPhoto != connection.photo {
                    Toggle(isOn: $updatePhoto) {
                        Text(connection.photo != nil ? "Update photo" : "Add photo").font(.caption)
                    }
                }

                // New feeds not already associated
                let existingFeedUrls = Set(connection.feeds.map(\.url))
                let newFeeds = metadata.feeds.filter { !existingFeedUrls.contains($0.url) }

                if !newFeeds.isEmpty {
                    Divider()
                    Text("Discovered Feeds").font(.subheadline).fontWeight(.medium)
                    ForEach(newFeeds, id: \.url) { feed in
                        Toggle(isOn: binding(for: feed.url, in: $selectedFeeds)) {
                            VStack(alignment: .leading) {
                                Text(feed.title ?? "Untitled").font(.caption)
                                Text("\(feed.url) (\(feed.format))").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                let existingProfileUrls = Set(connection.metadata.map(\.value))
                let newProfiles = metadata.socialProfiles.filter { !existingProfileUrls.contains($0.url) }

                if !newProfiles.isEmpty {
                    Divider()
                    Text("Discovered Profiles").font(.subheadline).fontWeight(.medium)
                    ForEach(newProfiles, id: \.url) { profile in
                        Toggle(isOn: binding(for: profile.url, in: $selectedProfiles)) {
                            Text("\(profile.fieldType.name): \(profile.url)").font(.caption)
                        }
                    }
                }

                if metadata.name == nil && metadata.photo == nil && newFeeds.isEmpty && newProfiles.isEmpty {
                    Text("No new metadata discovered.").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func loadPreview() async {
        guard !sourceUrl.isEmpty else {
            error = "No source URL available for this connection"
            isLoading = false
            return
        }

        let result = await ContactDiscoveryService.discover(url: sourceUrl)
        await MainActor.run {
            switch result {
            case .success(let metadata):
                discoveredMetadata = metadata
                selectedFeeds = Set(metadata.feeds.map(\.url))
                let existingUrls = Set(connection.metadata.map(\.value))
                selectedProfiles = Set(
                    metadata.socialProfiles.filter { !existingUrls.contains($0.url) }.map(\.url)
                )
            case .failure(let err):
                error = err.message
            }
            isLoading = false
        }
    }

    private func applyChanges() {
        guard let metadata = discoveredMetadata else { return }
        isSubmitting = true

        if updateName, let proposedName = metadata.name, proposedName != connection.name {
            connection.name = proposedName
        }
        if updatePhoto, let proposedPhoto = metadata.photo, proposedPhoto != connection.photo {
            connection.photo = proposedPhoto
        }

        // Add new feeds
        let existingFeedUrls = Set(connection.feeds.map(\.url))
        for feed in metadata.feeds where selectedFeeds.contains(feed.url) && !existingFeedUrls.contains(feed.url) {
            _ = FeedStore.create(in: modelContext, connection: connection, url: feed.url, title: feed.title)
        }

        // Add new profiles
        let existingProfileUrls = Set(connection.metadata.map(\.value))
        for profile in metadata.socialProfiles where selectedProfiles.contains(profile.url) && !existingProfileUrls.contains(profile.url) {
            _ = MetadataStore.createIfNotExists(
                in: modelContext, connection: connection,
                fieldType: profile.fieldType, value: profile.url
            )
        }

        try? modelContext.save()
        dismiss()
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
