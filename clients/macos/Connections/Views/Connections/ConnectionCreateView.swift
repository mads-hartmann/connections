import SwiftUI

struct ConnectionCreateView: View {
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var isLoading = false
    @State private var metadata: ContactMetadataResponse?
    @State private var error: String?

    var body: some View {
        if let metadata {
            ConnectionPreviewForm(metadata: metadata, sourceUrl: url, onCreated: {
                onCreated()
                dismiss()
            })
        } else {
            VStack(spacing: 16) {
                Text("Create Connection")
                    .font(.headline)

                TextField("URL", text: $url, prompt: Text("https://example.com"))
                    .textFieldStyle(.roundedBorder)

                Text("Paste a URL to discover the connection's name, feeds, and social profiles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Fetch") { fetchMetadata() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(url.isEmpty || isLoading)
                }

                if isLoading {
                    ProgressView()
                }
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
                let result = try await MetadataService.fetchContactMetadata(url: url)
                await MainActor.run {
                    metadata = result
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

struct ConnectionPreviewForm: View {
    let metadata: ContactMetadataResponse
    let sourceUrl: String
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedFeeds: Set<String>
    @State private var selectedProfiles: Set<String>
    @State private var isCreating = false
    @State private var error: String?

    init(metadata: ContactMetadataResponse, sourceUrl: String, onCreated: @escaping () -> Void) {
        self.metadata = metadata
        self.sourceUrl = sourceUrl
        self.onCreated = onCreated

        let suggestedName = metadata.name ?? (URL(string: sourceUrl)?.host ?? "")
        self._name = State(initialValue: suggestedName)
        self._selectedFeeds = State(initialValue: Set(metadata.feeds.map(\.url)))
        self._selectedProfiles = State(initialValue: Set(metadata.socialProfiles.map(\.url)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Connection")
                .font(.headline)

            LabeledContent("Source") { Text(sourceUrl).font(.caption) }

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            if let photo = metadata.photo {
                LabeledContent("Photo") { Text(photo).font(.caption).lineLimit(1) }
            }

            if let bio = metadata.bio {
                LabeledContent("Bio") { Text(bio).font(.caption).lineLimit(2) }
            }

            if !metadata.feeds.isEmpty {
                Divider()
                Text("Feeds").font(.subheadline).fontWeight(.medium)
                ForEach(metadata.feeds, id: \.url) { feed in
                    Toggle(isOn: binding(for: feed.url, in: $selectedFeeds)) {
                        VStack(alignment: .leading) {
                            Text(feed.title ?? "Untitled")
                                .font(.caption)
                            Text("\(feed.url) (\(feed.format))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !metadata.socialProfiles.isEmpty {
                Divider()
                Text("Profiles").font(.subheadline).fontWeight(.medium)
                ForEach(metadata.socialProfiles, id: \.url) { profile in
                    let classified = ProfileClassifier.classify(profile)
                    Toggle(isOn: binding(for: profile.url, in: $selectedProfiles)) {
                        Text("\(classified.fieldType.name): \(profile.url)")
                            .font(.caption)
                    }
                }
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { createConnection() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || isCreating)
            }

            if isCreating { ProgressView() }
        }
        .padding()
        .frame(width: 500)
    }

    private func createConnection() {
        isCreating = true
        error = nil
        Task {
            do {
                let connection = try await ConnectionService.create(
                    name: name.trimmingCharacters(in: .whitespaces),
                    url: sourceUrl,
                    photo: metadata.photo
                )

                // Create selected feeds
                let feedsToCreate = metadata.feeds.filter { selectedFeeds.contains($0.url) }
                for feed in feedsToCreate {
                    _ = try? await FeedService.create(connectionId: connection.id, url: feed.url, title: feed.title ?? "")
                }

                // Create selected profiles as metadata
                let profilesToCreate = metadata.socialProfiles.filter { selectedProfiles.contains($0.url) }
                for profile in profilesToCreate {
                    let classified = ProfileClassifier.classify(profile)
                    _ = try? await ConnectionService.createMetadata(
                        connectionId: connection.id,
                        fieldTypeId: classified.fieldType.id,
                        value: classified.url
                    )
                }

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
