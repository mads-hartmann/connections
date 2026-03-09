import SwiftUI
import SwiftData

struct ConnectionCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var url = ""
    @State private var isLoading = false
    @State private var discoveredMetadata: DiscoveredContactMetadata?
    @State private var error: String?

    // Preview form state
    @State private var name = ""
    @State private var selectedFeeds: Set<String> = []
    @State private var selectedProfiles: Set<String> = []
    @State private var isCreating = false

    var body: some View {
        if let metadata = discoveredMetadata {
            previewForm(metadata)
        } else {
            urlInputForm
        }
    }

    private var urlInputForm: some View {
        VStack(spacing: 16) {
            Text("Create Connection").font(.headline)

            TextField("URL", text: $url, prompt: Text("https://example.com"))
                .textFieldStyle(.roundedBorder)

            Text("Paste a URL to discover the connection's name, feeds, and social profiles.")
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

    private func previewForm(_ metadata: DiscoveredContactMetadata) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Connection").font(.headline)

            LabeledContent("Source") { Text(url).font(.caption) }

            TextField("Name", text: $name).textFieldStyle(.roundedBorder)

            if let photo = metadata.photo {
                LabeledContent("Photo") { Text(photo).font(.caption).lineLimit(1) }
            }

            if !metadata.feeds.isEmpty {
                Divider()
                Text("Feeds").font(.subheadline).fontWeight(.medium)
                ForEach(metadata.feeds, id: \.url) { feed in
                    Toggle(isOn: binding(for: feed.url, in: $selectedFeeds)) {
                        VStack(alignment: .leading) {
                            Text(feed.title ?? "Untitled").font(.caption)
                            Text("\(feed.url) (\(feed.format))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !metadata.socialProfiles.isEmpty {
                Divider()
                Text("Profiles").font(.subheadline).fontWeight(.medium)
                ForEach(metadata.socialProfiles, id: \.url) { profile in
                    Toggle(isOn: binding(for: profile.url, in: $selectedProfiles)) {
                        Text("\(profile.fieldType.name): \(profile.url)").font(.caption)
                    }
                }
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { createConnection(metadata) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || isCreating)
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
            let result = await ContactDiscoveryService.discover(url: url)
            await MainActor.run {
                switch result {
                case .success(let metadata):
                    discoveredMetadata = metadata
                    name = metadata.name ?? (URL(string: url)?.host ?? "")
                    selectedFeeds = Set(metadata.feeds.map(\.url))
                    selectedProfiles = Set(metadata.socialProfiles.map(\.url))
                case .failure(let msg):
                    error = msg
                }
                isLoading = false
            }
        }
    }

    private func createConnection(_ metadata: DiscoveredContactMetadata) {
        isCreating = true

        let connection = ConnectionStore.create(
            in: modelContext,
            name: name.trimmingCharacters(in: .whitespaces),
            photo: metadata.photo
        )

        // Create selected feeds
        for feed in metadata.feeds where selectedFeeds.contains(feed.url) {
            _ = FeedStore.create(in: modelContext, connection: connection, url: feed.url, title: feed.title)
        }

        // Create selected profiles as metadata
        for profile in metadata.socialProfiles where selectedProfiles.contains(profile.url) {
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
