import Foundation
import SwiftData

@Model
final class CDTag {
    @Attribute(.unique) var uid: UUID
    @Attribute(.unique) var name: String

    @Relationship(inverse: \CDConnection.tags)
    var connections: [CDConnection] = []

    @Relationship(inverse: \CDFeed.tags)
    var feeds: [CDFeed] = []

    @Relationship(inverse: \CDUri.tags)
    var uris: [CDUri] = []

    init(name: String) {
        self.uid = UUID()
        self.name = name
    }
}
