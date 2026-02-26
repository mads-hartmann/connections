import SwiftUI

struct TagListView: View {
    @State private var tags: [Tag] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var page = 1
    @State private var hasMore = false
    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(tags) { tag in
                    TagRowView(tag: tag, onRefresh: loadTags)
                }

                if hasMore {
                    Button("Load More") { loadMore() }
                        .frame(maxWidth: .infinity)
                }
            }
            .searchable(text: $searchText, prompt: "Search tags...")
            .onChange(of: searchText) { _, _ in
                Task { await search() }
            }
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Create Tag", systemImage: "plus") {
                        showCreateSheet = true
                    }
                }
            }
            .overlay {
                if isLoading && tags.isEmpty {
                    ProgressView()
                } else if tags.isEmpty && !isLoading {
                    ContentUnavailableView("No Tags", systemImage: "tag", description: Text("Create a tag to get started"))
                }
            }
            .task { loadTags() }
            .sheet(isPresented: $showCreateSheet) {
                TagCreateView(onCreated: loadTags)
            }
        }
    }

    private func loadTags() {
        page = 1
        isLoading = true
        Task {
            do {
                let response = try await TagService.list(page: 1, query: searchText.isEmpty ? nil : searchText)
                await MainActor.run {
                    tags = response.data
                    hasMore = response.page < response.totalPages
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func loadMore() {
        page += 1
        Task {
            do {
                let response = try await TagService.list(page: page, query: searchText.isEmpty ? nil : searchText)
                await MainActor.run {
                    tags.append(contentsOf: response.data)
                    hasMore = response.page < response.totalPages
                }
            } catch {
                await MainActor.run { page -= 1 }
            }
        }
    }

    private func search() async {
        page = 1
        do {
            let response = try await TagService.list(page: 1, query: searchText.isEmpty ? nil : searchText)
            await MainActor.run {
                tags = response.data
                hasMore = response.page < response.totalPages
            }
        } catch {}
    }
}

struct TagRowView: View {
    let tag: Tag
    let onRefresh: () -> Void

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var showUris = false

    var body: some View {
        NavigationLink(value: tag) {
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
            TagEditView(tag: tag, onSaved: onRefresh)
        }
        .confirmationDialog("Delete tag \"\(tag.name)\"?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteTag() }
        }
    }

    private func deleteTag() {
        Task {
            try? await TagService.delete(id: tag.id)
            await MainActor.run { onRefresh() }
        }
    }
}

struct TagUriListView: View {
    let tag: Tag

    @State private var uris: [UriEntry] = []
    @State private var isLoading = false
    @State private var page = 1
    @State private var hasMore = false

    var body: some View {
        List {
            ForEach(uris) { uri in
                UriRowView(uri: uri, onRefresh: loadUris)
            }

            if hasMore {
                Button("Load More") { loadMore() }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Tag: \(tag.name)")
        .overlay {
            if isLoading && uris.isEmpty {
                ProgressView()
            } else if uris.isEmpty && !isLoading {
                ContentUnavailableView("No URIs", systemImage: "doc.text")
            }
        }
        .task { loadUris() }
    }

    private func loadUris() {
        page = 1
        isLoading = true
        Task {
            do {
                let response = try await UriService.listByTag(tag: tag.name, page: 1)
                await MainActor.run {
                    uris = response.data
                    hasMore = response.page < response.totalPages
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func loadMore() {
        page += 1
        Task {
            do {
                let response = try await UriService.listByTag(tag: tag.name, page: page)
                await MainActor.run {
                    uris.append(contentsOf: response.data)
                    hasMore = response.page < response.totalPages
                }
            } catch {
                await MainActor.run { page -= 1 }
            }
        }
    }
}
