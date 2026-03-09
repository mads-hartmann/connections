import Foundation
import SwiftData

/// The type of metadata field (social profile, email, website, etc.)
enum CDMetadataFieldType: Int, Codable, CaseIterable, Identifiable {
    case bluesky = 1
    case email = 2
    case gitHub = 3
    case linkedIn = 4
    case mastodon = 5
    case website = 6
    case x = 7
    case other = 8
    case youTube = 9

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .bluesky: "Bluesky"
        case .email: "Email"
        case .gitHub: "GitHub"
        case .linkedIn: "LinkedIn"
        case .mastodon: "Mastodon"
        case .website: "Website"
        case .x: "X"
        case .other: "Other"
        case .youTube: "YouTube"
        }
    }
}

@Model
final class CDConnectionMetadata {
    @Attribute(.unique) var uid: UUID
    var fieldType: CDMetadataFieldType
    var value: String

    var connection: CDConnection?

    init(fieldType: CDMetadataFieldType, value: String, connection: CDConnection? = nil) {
        self.uid = UUID()
        self.fieldType = fieldType
        self.value = value
        self.connection = connection
    }
}
