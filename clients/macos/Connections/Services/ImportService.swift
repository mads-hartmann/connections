import Foundation

enum ImportService {
    private static var api: APIClient { .shared }

    static func previewOpml(content: String) async throws -> ImportPreviewResponse {
        guard let data = content.data(using: .utf8) else {
            throw APIError(message: "Failed to encode OPML content")
        }
        return try await api.postRaw("/import/opml/preview", body: data, contentType: "text/xml")
    }

    static func confirmImport(connections: [ImportConnectionInfo]) async throws -> ImportConfirmResponse {
        try await api.post("/import/opml/confirm", body: ImportConfirmRequest(connections: connections))
    }
}
