import Foundation
import SwiftData

@Model
final class CDConnection {
    @Attribute(.unique) var uid: UUID
    var name: String
    var photo: String?
    var note: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CDFeed.connection)
    var feeds: [CDFeed] = []

    @Relationship(deleteRule: .cascade, inverse: \CDConnectionMetadata.connection)
    var metadata: [CDConnectionMetadata] = []

    @Relationship(inverse: \CDUri.connection)
    var uris: [CDUri] = []

    var tags: [CDTag] = []

    // Computed counts
    var feedCount: Int { feeds.count }
    var uriCount: Int { uris.count }
    var unreadUriCount: Int { uris.filter { $0.readAt == nil }.count }

    init(name: String, photo: String? = nil, note: String? = nil) {
        self.uid = UUID()
        self.name = name
        self.photo = photo
        self.note = note
        self.createdAt = Date()
    }
}
