import Foundation

enum ConnectionService {
    private static var api: APIClient { .shared }

    static func list(page: Int = 1, query: String? = nil) async throws -> ConnectionsResponse {
        var params = ["page": "\(page)", "per_page": "20"]
        if let query, !query.isEmpty { params["query"] = query }
        return try await api.get("/connections", query: params)
    }

    static func get(id: Int) async throws -> ConnectionDetail {
        try await api.get("/connections/\(id)")
    }

    static func create(name: String, url: String? = nil, photo: String? = nil) async throws -> ConnectionDetail {
        struct Body: Encodable { let name: String; let url: String?; let photo: String? }
        return try await api.post("/connections", body: Body(name: name, url: url, photo: photo))
    }

    static func update(id: Int, name: String, photo: String? = nil) async throws -> ConnectionDetail {
        struct Body: Encodable { let name: String; let photo: String? }
        return try await api.put("/connections/\(id)", body: Body(name: name, photo: photo))
    }

    static func updateNote(id: Int, note: String?) async throws -> ConnectionDetail {
        struct Body: Encodable { let note: String? }
        return try await api.put("/connections/\(id)/note", body: Body(note: note))
    }

    static func delete(id: Int) async throws {
        try await api.delete("/connections/\(id)")
    }

    static func findByHost(_ host: String) async throws -> [Connection] {
        try await api.get("/connections/by-host", query: ["host": host])
    }

    // MARK: - Metadata

    static func createMetadata(connectionId: Int, fieldTypeId: Int, value: String) async throws -> ConnectionMetadata {
        struct Body: Encodable { let fieldTypeId: Int; let value: String }
        return try await api.post("/connections/\(connectionId)/metadata", body: Body(fieldTypeId: fieldTypeId, value: value))
    }

    static func updateMetadata(connectionId: Int, metadataId: Int, value: String) async throws -> ConnectionMetadata {
        struct Body: Encodable { let value: String }
        return try await api.put("/connections/\(connectionId)/metadata/\(metadataId)", body: Body(value: value))
    }

    static func deleteMetadata(connectionId: Int, metadataId: Int) async throws {
        try await api.delete("/connections/\(connectionId)/metadata/\(metadataId)")
    }

    static func fetchRefreshPreview(connectionId: Int) async throws -> RefreshMetadataPreview {
        try await api.get("/connections/\(connectionId)/refresh-metadata")
    }
}
