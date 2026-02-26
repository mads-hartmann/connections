import Foundation

enum UriKind: String, Codable, CaseIterable, Identifiable {
    case blog, video, tweet, book, site, podcast, paper, unknown

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

struct UriEntry: Codable, Identifiable, Hashable {
    let id: Int
    let feedId: Int?
    let connectionId: Int?
    let connectionName: String?
    var kind: UriKind
    var title: String?
    let url: String
    let publishedAt: String?
    let content: String?
    let author: String?
    let imageUrl: String?
    let createdAt: String
    var readAt: String?
    var readLaterAt: String?
    var tags: [Tag]
    let ogTitle: String?
    let ogDescription: String?
    let ogImage: String?
    let ogSiteName: String?
    let ogFetchedAt: String?
    let ogFetchError: String?
    var vote: Int?
    let votedAt: String?
    var note: String?

    var isRead: Bool { readAt != nil }
    var isReadLater: Bool { readLaterAt != nil }
    var isUpvoted: Bool { vote == 1 }
    var isDownvoted: Bool { vote == -1 }
    var displayTitle: String { title ?? "Untitled" }
}

struct UrisResponse: Codable {
    let data: [UriEntry]
    let page: Int
    let perPage: Int
    let total: Int
    let totalPages: Int
}

struct MarkAllReadResponse: Codable {
    let markedRead: Int
}

struct UriContent: Codable {
    let markdown: String
}

struct CreateUriRequest: Codable {
    let url: String
    var connectionId: Int?
    var kind: UriKind?
    var title: String?
}
