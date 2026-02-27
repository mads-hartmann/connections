import Foundation

struct Feed: Codable, Identifiable, Hashable {
    let id: Int
    let connectionId: Int
    var url: String
    var title: String?
    let createdAt: String
    let lastFetchedAt: String?
}

struct FeedsResponse: Codable {
    let data: [Feed]
    let page: Int
    let perPage: Int
    let total: Int
    let totalPages: Int
}
