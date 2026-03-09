import SwiftUI
import SwiftData

struct TagListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CDTag.name) private var tags: [CDTag]

    @State private var searchText = ""
    @State private var showCreateSheet = false

    private var filteredTags: [CDTag] {
        if searchText.isEmpty { return tags }
        return tags.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredTags) { tag in
                    TagRowView(tag: tag)
                }
            }
            .searchable(text: $searchText, prompt: "Search tags...")
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Create Tag", systemImage: "plus") {
                        showCreateSheet = true
                    }
                }
            }
            .overlay {
                if filteredTags.isEmpty {
                    ContentUnavailableView("No Tags", systemImage: "tag", description: Text("Create a tag to get started"))
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                TagCreateView()
            }
        }
    }
}

struct TagRowView: View {
    let tag: CDTag

    @Environment(\.modelContext) private var modelContext
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var showUris = false

    var body: some View {
        NavigationLink(value: tag.uid) {
            Label(tag.name, systemImage: "tag")
        }
        .contextMenu {
            Button("View URIs") { showUris = true }
            Button("Edit") { showEditSheet = true }
            Divider()
            Button("Delete", role: .destructive) { showDeleteConfirm = true }
        }
        .navigationDestination(isPresented: $showUris) {
            TagUriListView(tag: tag)
        }
        .sheet(isPresented: $showEditSheet) {
            TagEditView(tag: tag)
        }
        .confirmationDialog("Delete tag \"\(tag.name)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                TagStore.delete(in: modelContext, tag: tag)
            }
        }
    }
}

struct TagUriListView: View {
    let tag: CDTag

    private var uris: [CDUri] {
        UriStore.listByTag(tag)
    }

    var body: some View {
        List {
            ForEach(uris) { uri in
                UriRowView(uri: uri)
            }
        }
        .navigationTitle("Tag: \(tag.name)")
        .overlay {
            if uris.isEmpty {
                ContentUnavailableView("No URIs", systemImage: "doc.text")
            }
        }
    }
}
