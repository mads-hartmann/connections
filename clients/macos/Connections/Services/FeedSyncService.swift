import Foundation
import SwiftData
import os

/// Handles periodic RSS/Atom feed synchronization.
@Observable
final class FeedSyncService {
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var lastSyncError: String?

    private let logger = Logger(subsystem: "Connections", category: "FeedSync")

    /// Sync all feeds: fetch, parse, upsert URIs, associate tags.
    func syncAllFeeds(context: ModelContext) async {
        guard !isSyncing else { return }

        await MainActor.run { isSyncing = true }
        logger.info("Starting feed sync")

        let feeds = (try? context.fetch(FetchDescriptor<CDFeed>())) ?? []
        var totalProcessed = 0

        for feed in feeds {
            do {
                let count = try await syncFeed(feed, context: context)
                totalProcessed += count
            } catch {
                logger.error("Failed to sync feed \(feed.url): \(error.localizedDescription)")
            }
        }

        try? context.save()

        logger.info("Feed sync complete: \(totalProcessed) URIs processed across \(feeds.count) feeds")

        await MainActor.run {
            lastSyncDate = Date()
            lastSyncError = nil
            isSyncing = false
        }
    }

    /// Sync a single feed.
    @discardableResult
    func syncFeed(_ feed: CDFeed, context: ModelContext) async throws -> Int {
        guard let url = URL(string: feed.url) else {
            throw FeedSyncError.invalidURL(feed.url)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let items = FeedParserService.parseItems(from: data)

        // Collect feed-level tag UIDs for applying to new URIs
        let feedTags = feed.tags

        var count = 0
        for item in items {
            guard let itemUrl = item.url else { continue }

            let uri = UriStore.upsert(
                in: context,
                feed: feed,
                url: itemUrl,
                kind: .blog,
                title: item.title,
                publishedAt: item.publishedAt,
                content: item.content,
                author: item.author,
                imageUrl: item.imageUrl
            )

            // Associate category tags from the feed item
            for categoryName in item.categories {
                let tag = TagStore.getOrCreate(in: context, name: categoryName)
                TagStore.addToUri(tag, uri: uri)
            }

            // Apply feed-level tags
            for tag in feedTags {
                TagStore.addToUri(tag, uri: uri)
            }

            count += 1
        }

        FeedStore.updateLastFetched(feed)
        return count
    }

    /// Refresh a single feed (user-triggered).
    func refreshFeed(_ feed: CDFeed, context: ModelContext) async {
        do {
            let count = try await syncFeed(feed, context: context)
            try? context.save()
            logger.info("Refreshed feed \(feed.url): \(count) URIs")
        } catch {
            logger.error("Failed to refresh feed \(feed.url): \(error.localizedDescription)")
        }
    }
}

enum FeedSyncError: LocalizedError {
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): "Invalid feed URL: \(url)"
        }
    }
}
