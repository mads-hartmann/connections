import Foundation

struct Tag: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
}

struct TagsResponse: Codable {
    let data: [Tag]
    let page: Int
    let perPage: Int
    let total: Int
    let totalPages: Int
}
