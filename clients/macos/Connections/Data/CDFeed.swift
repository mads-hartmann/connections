import Foundation
import SwiftData

@Model
final class CDFeed {
    @Attribute(.unique) var uid: UUID
    var url: String
    var title: String?
    var createdAt: Date
    var lastFetchedAt: Date?

    var connection: CDConnection?

    @Relationship(deleteRule: .cascade, inverse: \CDUri.feed)
    var uris: [CDUri] = []

    var tags: [CDTag] = []

    init(url: String, title: String? = nil, connection: CDConnection? = nil) {
        self.uid = UUID()
        self.url = url
        self.title = title
        self.connection = connection
        self.createdAt = Date()
    }
}
