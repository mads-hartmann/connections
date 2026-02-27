import Foundation

enum FeedService {
    private static var api: APIClient { .shared }

    static func listByConnection(connectionId: Int, page: Int = 1) async throws -> FeedsResponse {
        try await api.get("/connections/\(connectionId)/feeds", query: ["page": "\(page)", "per_page": "20"])
    }

    static func listAll(page: Int = 1, query: String? = nil) async throws -> FeedsResponse {
        var params = ["page": "\(page)", "per_page": "20"]
        if let query, !query.isEmpty { params["query"] = query }
        return try await api.get("/feeds", query: params)
    }

    static func create(connectionId: Int, url: String, title: String) async throws -> Feed {
        struct Body: Encodable { let connectionId: Int; let url: String; let title: String }
        return try await api.post("/connections/\(connectionId)/feeds", body: Body(connectionId: connectionId, url: url, title: title))
    }

    static func update(id: Int, url: String, title: String) async throws -> Feed {
        struct Body: Encodable { let url: String; let title: String }
        return try await api.put("/feeds/\(id)", body: Body(url: url, title: title))
    }

    static func delete(id: Int) async throws {
        try await api.delete("/feeds/\(id)")
    }

    static func refresh(id: Int) async throws -> Feed {
        try await api.postNoBody("/feeds/\(id)/refresh")
    }
}
