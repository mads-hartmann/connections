import Foundation
import SwiftData

/// The kind of content a URI points to.
enum CDUriKind: String, Codable, CaseIterable, Identifiable {
    case blog, video, tweet, book, site, podcast, paper, unknown

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

@Model
final class CDUri {
    @Attribute(.unique) var uid: UUID
    var kind: CDUriKind
    var title: String?
    var url: String
    var publishedAt: Date?
    var content: String?
    var author: String?
    var imageUrl: String?
    var createdAt: Date
    var readAt: Date?
    var readLaterAt: Date?

    // OpenGraph / link metadata
    var ogTitle: String?
    var ogDescription: String?
    var ogImage: String?
    var ogSiteName: String?
    var ogFetchedAt: Date?
    var ogFetchError: String?

    var vote: Int?
    var votedAt: Date?
    var note: String?

    var feed: CDFeed?
    var connection: CDConnection?
    var tags: [CDTag] = []

    // Convenience
    var isRead: Bool { readAt != nil }
    var isReadLater: Bool { readLaterAt != nil }
    var isUpvoted: Bool { vote == 1 }
    var isDownvoted: Bool { vote == -1 }
    var displayTitle: String { title ?? "Untitled" }
    var connectionName: String? { connection?.name }

    init(
        url: String,
        kind: CDUriKind = .unknown,
        title: String? = nil,
        publishedAt: Date? = nil,
        content: String? = nil,
        author: String? = nil,
        imageUrl: String? = nil,
        feed: CDFeed? = nil,
        connection: CDConnection? = nil
    ) {
        self.uid = UUID()
        self.url = url
        self.kind = kind
        self.title = title
        self.publishedAt = publishedAt
        self.content = content
        self.author = author
        self.imageUrl = imageUrl
        self.feed = feed
        self.connection = connection
        self.createdAt = Date()
    }
}
