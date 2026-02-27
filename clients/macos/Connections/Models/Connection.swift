import Foundation

struct ConnectionMetadata: Codable, Identifiable, Hashable {
    let id: Int
    let fieldType: MetadataFieldType
    var value: String
}

struct Connection: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var photo: String?
    var note: String?
    let feedCount: Int
    let uriCount: Int
    let unreadUriCount: Int
    var metadata: [ConnectionMetadata]
    var tags: [Tag]
}

struct ConnectionDetail: Codable, Identifiable {
    let id: Int
    var name: String
    var photo: String?
    var note: String?
    var metadata: [ConnectionMetadata]
}

struct ConnectionsResponse: Codable {
    let data: [Connection]
    let page: Int
    let perPage: Int
    let total: Int
    let totalPages: Int
}

// Refresh metadata types

struct RefreshMetadataFeed: Codable, Hashable {
    let url: String
    let title: String?
    let format: String
}

struct RefreshMetadataProfile: Codable, Hashable {
    let url: String
    let fieldType: MetadataFieldType
}

struct RefreshMetadataPreview: Codable {
    let connectionId: Int
    let sourceUrl: String
    let proposedName: String?
    let proposedPhoto: String?
    let proposedFeeds: [RefreshMetadataFeed]
    let proposedProfiles: [RefreshMetadataProfile]
    let currentName: String
    let currentPhoto: String?
    let currentMetadata: [ConnectionMetadata]
}
