import SwiftUI

struct FeedCreateView: View {
    let connectionId: Int
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var title = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Feed")
                .font(.headline)

            TextField("Feed URL", text: $url, prompt: Text("https://example.com/feed.xml"))
                .textFieldStyle(.roundedBorder)

            TextField("Title", text: $title, prompt: Text("Feed title"))
                .textFieldStyle(.roundedBorder)

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(url.isEmpty || isCreating)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func create() {
        isCreating = true
        error = nil
        Task {
            do {
                _ = try await FeedService.create(connectionId: connectionId, url: url, title: title)
                await MainActor.run {
                    onCreated()
                    dismiss()
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

struct FeedEditView: View {
    let feed: Feed
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var url: String
    @State private var title: String
    @State private var isSaving = false
    @State private var error: String?

    init(feed: Feed, onSaved: @escaping () -> Void) {
        self.feed = feed
        self.onSaved = onSaved
        self._url = State(initialValue: feed.url)
        self._title = State(initialValue: feed.title ?? "")
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Feed")
                .font(.headline)

            TextField("Feed URL", text: $url)
                .textFieldStyle(.roundedBorder)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(url.isEmpty || isSaving)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func save() {
        isSaving = true
        Task {
            do {
                _ = try await FeedService.update(id: feed.id, url: url, title: title)
                await MainActor.run {
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}
