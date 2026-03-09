import SwiftUI

struct FeedCreateView: View {
    let connection: CDConnection

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var url = ""
    @State private var title = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Feed").font(.headline)

            TextField("Feed URL", text: $url, prompt: Text("https://example.com/feed.xml"))
                .textFieldStyle(.roundedBorder)

            TextField("Title", text: $title, prompt: Text("Feed title"))
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(url.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func create() {
        _ = FeedStore.create(
            in: modelContext,
            connection: connection,
            url: url,
            title: title.isEmpty ? nil : title
        )
        try? modelContext.save()
        dismiss()
    }
}

struct FeedEditView: View {
    let feed: CDFeed

    @Environment(\.dismiss) private var dismiss
    @State private var url: String
    @State private var title: String

    init(feed: CDFeed) {
        self.feed = feed
        self._url = State(initialValue: feed.url)
        self._title = State(initialValue: feed.title ?? "")
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Feed").font(.headline)

            TextField("Feed URL", text: $url).textFieldStyle(.roundedBorder)
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(url.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func save() {
        FeedStore.update(feed, url: url, title: title.isEmpty ? nil : title)
        dismiss()
    }
}
