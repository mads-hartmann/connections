import Foundation

enum MetadataService {
    private static var api: APIClient { .shared }

    static func fetchContactMetadata(url: String) async throws -> ContactMetadataResponse {
        try await api.get("/discovery/connection-metadata", query: ["url": url])
    }

    static func fetchUriMetadata(url: String) async throws -> UriMetadataResponse {
        try await api.get("/discovery/uri-metadata", query: ["url": url])
    }
}
