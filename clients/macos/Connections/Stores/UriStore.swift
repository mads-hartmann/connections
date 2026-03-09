import Foundation
import SwiftData

enum UriStore {

    static func create(
        in context: ModelContext,
        url: String,
        kind: CDUriKind = .unknown,
        title: String? = nil,
        publishedAt: Date? = nil,
        content: String? = nil,
        author: String? = nil,
        imageUrl: String? = nil,
        feed: CDFeed? = nil,
        connection: CDConnection? = nil
    ) -> CDUri {
        let uri = CDUri(
            url: url, kind: kind, title: title,
            publishedAt: publishedAt, content: content,
            author: author, imageUrl: imageUrl,
            feed: feed, connection: connection
        )
        context.insert(uri)
        return uri
    }

    /// Upsert a URI by (feed, url) for feed-sourced URIs.
    /// Returns the existing URI if found, or creates a new one.
    static func upsert(
        in context: ModelContext,
        feed: CDFeed,
        url: String,
        kind: CDUriKind = .blog,
        title: String?,
        publishedAt: Date?,
        content: String?,
        author: String?,
        imageUrl: String?
    ) -> CDUri {
        // Check if URI already exists for this feed+url
        let feedUID = feed.uid
        let descriptor = FetchDescriptor<CDUri>(
            predicate: #Predicate<CDUri> { uri in
                uri.url == url && uri.feed?.uid == feedUID
            }
        )
        if let existing = try? context.fetch(descriptor).first {
            // Update mutable fields
            if let title { existing.title = title }
            if let content { existing.content = content }
            if let author { existing.author = author }
            if let imageUrl { existing.imageUrl = imageUrl }
            if let publishedAt { existing.publishedAt = publishedAt }
            return existing
        }

        return create(
            in: context, url: url, kind: kind, title: title,
            publishedAt: publishedAt, content: content,
            author: author, imageUrl: imageUrl,
            feed: feed, connection: feed.connection
        )
    }

    static func get(in context: ModelContext, uid: UUID) -> CDUri? {
        let descriptor = FetchDescriptor<CDUri>(
            predicate: #Predicate { $0.uid == uid }
        )
        return try? context.fetch(descriptor).first
    }

    static func listAll(
        in context: ModelContext,
        query: String? = nil,
        unreadOnly: Bool = false,
        readLaterOnly: Bool = false,
        upvotedOnly: Bool = false,
        downvotedOnly: Bool = false,
        orphanOnly: Bool = false,
        tag: String? = nil
    ) -> [CDUri] {
        var descriptor = FetchDescriptor<CDUri>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )

        // Build predicate based on filters
        // SwiftData predicates don't support complex optional chaining well,
        // so we fetch all and filter in memory for complex cases.
        if let query, !query.isEmpty {
            descriptor.predicate = #Predicate<CDUri> { uri in
                uri.url.localizedStandardContains(query)
                    || (uri.title?.localizedStandardContains(query) ?? false)
            }
        }

        var results = (try? context.fetch(descriptor)) ?? []

        if unreadOnly {
            results = results.filter { $0.readAt == nil }
        }
        if readLaterOnly {
            results = results.filter { $0.readLaterAt != nil }
        }
        if upvotedOnly {
            results = results.filter { $0.vote == 1 }
        }
        if downvotedOnly {
            results = results.filter { $0.vote == -1 }
        }
        if orphanOnly {
            results = results.filter { $0.connection == nil && $0.feed == nil }
        }
        if let tag {
            results = results.filter { uri in
                uri.tags.contains { $0.name == tag }
            }
        }

        return results
    }

    static func listByFeed(_ feed: CDFeed) -> [CDUri] {
        feed.uris.sorted {
            ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt)
        }
    }

    static func listByConnection(
        _ connection: CDConnection,
        unreadOnly: Bool = false
    ) -> [CDUri] {
        var results = connection.uris.sorted {
            ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt)
        }
        if unreadOnly {
            results = results.filter { $0.readAt == nil }
        }
        return results
    }

    static func listByTag(_ tag: CDTag) -> [CDUri] {
        tag.uris.sorted {
            ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt)
        }
    }

    static func markRead(_ uri: CDUri, read: Bool) {
        uri.readAt = read ? Date() : nil
    }

    static func markReadLater(_ uri: CDUri, readLater: Bool) {
        uri.readLaterAt = readLater ? Date() : nil
    }

    static func vote(_ uri: CDUri, vote: Int?) {
        uri.vote = vote
        uri.votedAt = vote != nil ? Date() : nil
    }

    static func updateNote(_ uri: CDUri, note: String?) {
        uri.note = note
    }

    static func markAllRead(uris: [CDUri]) -> Int {
        var count = 0
        let now = Date()
        for uri in uris where uri.readAt == nil {
            uri.readAt = now
            count += 1
        }
        return count
    }

    static func markAllReadGlobal(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<CDUri>(
            predicate: #Predicate<CDUri> { $0.readAt == nil }
        )
        let unread = (try? context.fetch(descriptor)) ?? []
        return markAllRead(uris: unread)
    }

    static func markAllReadByFeed(_ feed: CDFeed) -> Int {
        markAllRead(uris: feed.uris)
    }

    static func markAllReadByConnection(_ connection: CDConnection) -> Int {
        markAllRead(uris: connection.uris)
    }

    static func delete(in context: ModelContext, uri: CDUri) {
        context.delete(uri)
    }

    static func countUnread(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<CDUri>(
            predicate: #Predicate<CDUri> { $0.readAt == nil }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    static func countReadLater(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<CDUri>(
            predicate: #Predicate<CDUri> { $0.readLaterAt != nil }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    static func countUpvoted(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<CDUri>(
            predicate: #Predicate<CDUri> { $0.vote == 1 }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    static func countOrphan(in context: ModelContext) -> Int {
        let all = (try? context.fetch(FetchDescriptor<CDUri>())) ?? []
        return all.filter { $0.connection == nil && $0.feed == nil }.count
    }

    static func listNeedingMetadata(in context: ModelContext, limit: Int = 50) -> [CDUri] {
        let all = (try? context.fetch(FetchDescriptor<CDUri>())) ?? []
        return Array(
            all.filter { $0.ogFetchedAt == nil && $0.ogFetchError == nil }
                .prefix(limit)
        )
    }
}
