import Foundation

enum TagService {
    private static var api: APIClient { .shared }

    static func list(page: Int = 1, query: String? = nil) async throws -> TagsResponse {
        var params = ["page": "\(page)", "per_page": "20"]
        if let query, !query.isEmpty { params["query"] = query }
        return try await api.get("/tags", query: params)
    }

    static func listAll() async throws -> [Tag] {
        var allTags: [Tag] = []
        var page = 1
        while true {
            let response = try await list(page: page)
            allTags.append(contentsOf: response.data)
            if page >= response.totalPages { break }
            page += 1
        }
        return allTags
    }

    static func get(id: Int) async throws -> Tag {
        try await api.get("/tags/\(id)")
    }

    static func create(name: String) async throws -> Tag {
        struct Body: Encodable { let name: String }
        return try await api.post("/tags", body: Body(name: name))
    }

    static func update(id: Int, name: String) async throws -> Tag {
        struct Body: Encodable { let name: String }
        return try await api.patch("/tags/\(id)", body: Body(name: name))
    }

    static func delete(id: Int) async throws {
        try await api.delete("/tags/\(id)")
    }

    // MARK: - Connection Tags

    static func listByConnection(connectionId: Int) async throws -> [Tag] {
        try await api.get("/connections/\(connectionId)/tags")
    }

    static func addToConnection(connectionId: Int, tagId: Int) async throws {
        try await api.postVoid("/connections/\(connectionId)/tags/\(tagId)")
    }

    static func removeFromConnection(connectionId: Int, tagId: Int) async throws {
        try await api.delete("/connections/\(connectionId)/tags/\(tagId)")
    }

    // MARK: - Feed Tags

    static func listByFeed(feedId: Int) async throws -> [Tag] {
        try await api.get("/feeds/\(feedId)/tags")
    }

    static func addToFeed(feedId: Int, tagId: Int) async throws {
        try await api.postVoid("/feeds/\(feedId)/tags/\(tagId)")
    }

    static func removeFromFeed(feedId: Int, tagId: Int) async throws {
        try await api.delete("/feeds/\(feedId)/tags/\(tagId)")
    }

    // MARK: - URI Tags

    static func addToUri(uriId: Int, tagId: Int) async throws {
        try await api.postVoid("/uris/\(uriId)/tags/\(tagId)")
    }

    static func removeFromUri(uriId: Int, tagId: Int) async throws {
        try await api.delete("/uris/\(uriId)/tags/\(tagId)")
    }
}
