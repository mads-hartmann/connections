import Foundation

struct ImportFeedInfo: Codable, Hashable {
    let url: String
    let title: String?
}

struct ImportConnectionInfo: Codable, Hashable, Identifiable {
    let name: String
    let feeds: [ImportFeedInfo]
    let tags: [String]

    var id: String { name }
}

struct ImportError: Codable, Hashable {
    let url: String
    let error: String
}

struct ImportPreviewResponse: Codable {
    let connections: [ImportConnectionInfo]
    let errors: [ImportError]
}

struct ImportConfirmRequest: Codable {
    let connections: [ImportConnectionInfo]
}

struct ImportConfirmResponse: Codable {
    let createdConnections: Int
    let createdFeeds: Int
    let createdTags: Int
}
