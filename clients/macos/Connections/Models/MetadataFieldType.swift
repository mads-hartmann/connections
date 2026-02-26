import Foundation

struct MetadataFieldType: Codable, Identifiable, Hashable {
    let id: Int
    let name: String

    static let allTypes: [MetadataFieldType] = [
        MetadataFieldType(id: 1, name: "Bluesky"),
        MetadataFieldType(id: 2, name: "Email"),
        MetadataFieldType(id: 3, name: "GitHub"),
        MetadataFieldType(id: 4, name: "LinkedIn"),
        MetadataFieldType(id: 5, name: "Mastodon"),
        MetadataFieldType(id: 6, name: "Website"),
        MetadataFieldType(id: 7, name: "X"),
        MetadataFieldType(id: 8, name: "Other"),
    ]
}
