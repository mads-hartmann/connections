import Foundation

struct ClassifiedProfile: Codable, Hashable {
    let url: String
    let type: String
}

struct ContactMetadataResponse: Codable {
    let name: String?
    let url: String?
    let email: String?
    let photo: String?
    let bio: String?
    let location: String?
    let feeds: [DiscoveredFeed]
    let socialProfiles: [ClassifiedProfile]
}

struct DiscoveredFeed: Codable, Hashable {
    let url: String
    let title: String?
    let format: String
}

struct UriMetadataResponse: Codable {
    let title: String?
    let description: String?
    let image: String?
    let publishedAt: String?
    let authorName: String?
    let siteName: String?
    let canonicalUrl: String?
    let tags: [String]
    let contentType: String?
}

// Maps profile type names to field type IDs
enum ProfileClassifier {
    private static let fieldTypeMap: [String: MetadataFieldType] = [
        "Bluesky": MetadataFieldType(id: 1, name: "Bluesky"),
        "Email": MetadataFieldType(id: 2, name: "Email"),
        "GitHub": MetadataFieldType(id: 3, name: "GitHub"),
        "LinkedIn": MetadataFieldType(id: 4, name: "LinkedIn"),
        "Mastodon": MetadataFieldType(id: 5, name: "Mastodon"),
        "Website": MetadataFieldType(id: 6, name: "Website"),
        "X": MetadataFieldType(id: 7, name: "X"),
        "Other": MetadataFieldType(id: 8, name: "Other"),
    ]

    static func classify(_ profile: ClassifiedProfile) -> (url: String, fieldType: MetadataFieldType) {
        let fieldType = fieldTypeMap[profile.type] ?? fieldTypeMap["Other"]!
        return (profile.url, fieldType)
    }
}
