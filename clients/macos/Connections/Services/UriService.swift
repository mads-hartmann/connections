import Foundation

enum UriService {
    private static var api: APIClient { .shared }

    static func listAll(
        page: Int = 1,
        query: String? = nil,
        unread: Bool = false,
        readLater: Bool = false,
        upvoted: Bool = false,
        downvoted: Bool = false,
        orphan: Bool = false
    ) async throws -> UrisResponse {
        var params = ["page": "\(page)", "per_page": "20"]
        if let query, !query.isEmpty { params["query"] = query }
        if unread { params["unread"] = "true" }
        if readLater { params["read_later"] = "true" }
        if upvoted { params["upvoted"] = "true" }
        if downvoted { params["downvoted"] = "true" }
        if orphan { params["orphan"] = "true" }
        return try await api.get("/uris", query: params)
    }

    static func listByFeed(feedId: Int, page: Int = 1) async throws -> UrisResponse {
        try await api.get("/feeds/\(feedId)/uris", query: ["page": "\(page)", "per_page": "20"])
    }

    static func listByConnection(connectionId: Int, page: Int = 1, unread: Bool = false) async throws -> UrisResponse {
        var params = ["page": "\(page)", "per_page": "20"]
        if unread { params["unread"] = "true" }
        return try await api.get("/connections/\(connectionId)/uris", query: params)
    }

    static func listByTag(tag: String, page: Int = 1) async throws -> UrisResponse {
        try await api.get("/uris", query: ["page": "\(page)", "per_page": "20", "tag": tag])
    }

    static func markRead(id: Int, read: Bool) async throws -> UriEntry {
        struct Body: Encodable { let read: Bool }
        return try await api.post("/uris/\(id)/read", body: Body(read: read))
    }

    static func markReadLater(id: Int, readLater: Bool) async throws -> UriEntry {
        struct Body: Encodable { let readLater: Bool }
        return try await api.post("/uris/\(id)/read-later", body: Body(readLater: readLater))
    }

    static func vote(id: Int, vote: Int?) async throws -> UriEntry {
        struct Body: Encodable { let vote: Int? }
        return try await api.post("/uris/\(id)/vote", body: Body(vote: vote))
    }

    static func refreshMetadata(id: Int) async throws -> UriEntry {
        try await api.postNoBody("/uris/\(id)/refresh-metadata")
    }

    static func delete(id: Int) async throws {
        try await api.delete("/uris/\(id)")
    }

    static func create(_ request: CreateUriRequest) async throws -> UriEntry {
        try await api.post("/uris", body: request)
    }

    static func updateNote(id: Int, note: String?) async throws -> UriEntry {
        struct Body: Encodable { let note: String? }
        return try await api.put("/uris/\(id)/note", body: Body(note: note))
    }

    static func fetchContent(id: Int) async throws -> UriContent {
        try await api.get("/uris/\(id)/content")
    }

    // MARK: - Mark All Read

    static func markAllReadGlobal() async throws -> MarkAllReadResponse {
        try await api.postNoBody("/uris/mark-all-read")
    }

    static func markAllReadByFeed(feedId: Int) async throws -> MarkAllReadResponse {
        try await api.postNoBody("/feeds/\(feedId)/uris/mark-all-read")
    }

    static func markAllReadByConnection(connectionId: Int) async throws -> MarkAllReadResponse {
        try await api.postNoBody("/connections/\(connectionId)/uris/mark-all-read")
    }
}
