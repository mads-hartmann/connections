import Foundation
import SwiftData

enum FeedStore {

    static func create(
        in context: ModelContext,
        connection: CDConnection,
        url: String,
        title: String?
    ) -> CDFeed {
        let feed = CDFeed(url: url, title: title, connection: connection)
        context.insert(feed)
        return feed
    }

    static func all(in context: ModelContext, query: String? = nil) -> [CDFeed] {
        var descriptor = FetchDescriptor<CDFeed>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let query, !query.isEmpty {
            descriptor.predicate = #Predicate<CDFeed> { feed in
                feed.url.localizedStandardContains(query)
                    || (feed.title?.localizedStandardContains(query) ?? false)
            }
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func listByConnection(_ connection: CDConnection) -> [CDFeed] {
        connection.feeds.sorted { ($0.title ?? $0.url) < ($1.title ?? $1.url) }
    }

    static func get(in context: ModelContext, uid: UUID) -> CDFeed? {
        let descriptor = FetchDescriptor<CDFeed>(
            predicate: #Predicate { $0.uid == uid }
        )
        return try? context.fetch(descriptor).first
    }

    static func update(_ feed: CDFeed, url: String, title: String?) {
        feed.url = url
        feed.title = title
    }

    static func delete(in context: ModelContext, feed: CDFeed) {
        context.delete(feed)
    }

    static func updateLastFetched(_ feed: CDFeed) {
        feed.lastFetchedAt = Date()
    }
}
