import Foundation
import SwiftData
import os

/// Preview data for an OPML import — one connection with its feeds and tags.
struct ImportConnectionPreview: Identifiable, Hashable {
    let name: String
    let feeds: [ImportFeedPreview]
    let tags: [String]

    var id: String { name }
}

struct ImportFeedPreview: Hashable {
    let url: String
    let title: String?
}

struct ImportErrorInfo: Hashable {
    let url: String
    let error: String
}

struct ImportPreview {
    let connections: [ImportConnectionPreview]
    let errors: [ImportErrorInfo]
}

struct ImportResult {
    let createdConnections: Int
    let createdFeeds: Int
    let createdTags: Int
}

/// Handles OPML import: parse, preview (with feed metadata fetch), and confirm.
enum OpmlImportService {

    private static let logger = Logger(subsystem: "Connections", category: "OpmlImport")
    private static let maxConcurrentFetches = 5
    private static let fetchTimeoutSeconds: TimeInterval = 10

    /// Parse OPML and generate a preview by fetching feed metadata.
    static func preview(opmlContent: String) async -> Result<ImportPreview, OpmlParseError> {
        let parseResult: OpmlParseResult
        switch OpmlSAXParser.parse(opmlContent) {
        case .success(let result): parseResult = result
        case .failure(let error): return .failure(error)
        }

        // Fetch metadata for each feed with concurrency limiting
        var successes: [(OpmlFeedEntry, FeedMetadata)] = []
        var errors: [ImportErrorInfo] = []

        // Process in batches to limit concurrency
        let entries = parseResult.feeds
        for batch in stride(from: 0, to: entries.count, by: maxConcurrentFetches) {
            let end = min(batch + maxConcurrentFetches, entries.count)
            let batchEntries = Array(entries[batch..<end])

            await withTaskGroup(of: (OpmlFeedEntry, FeedMetadata?, String?).self) { group in
                for entry in batchEntries {
                    group.addTask {
                        do {
                            let metadata = try await withThrowingTaskGroup(of: FeedMetadata?.self) { inner in
                                inner.addTask {
                                    await FeedParserService.fetchMetadata(url: entry.url)
                                }
                                inner.addTask {
                                    try await Task.sleep(for: .seconds(fetchTimeoutSeconds))
                                    return nil
                                }
                                for try await result in inner {
                                    if let result {
                                        inner.cancelAll()
                                        return result
                                    }
                                }
                                return nil
                            }
                            return (entry, metadata, nil)
                        } catch {
                            return (entry, nil, error.localizedDescription)
                        }
                    }
                }

                for await (entry, metadata, error) in group {
                    if let metadata {
                        successes.append((entry, metadata))
                    } else {
                        errors.append(ImportErrorInfo(
                            url: entry.url,
                            error: error ?? "Timeout"
                        ))
                    }
                }
            }
        }

        // Group by author name
        var byAuthor: [String: (feeds: [ImportFeedPreview], tags: [String])] = [:]

        for (entry, metadata) in successes {
            let authorName = metadata.author
                ?? metadata.title
                ?? entry.title
                ?? "Unknown"

            let feed = ImportFeedPreview(
                url: entry.url,
                title: entry.title ?? metadata.title
            )

            var existing = byAuthor[authorName] ?? (feeds: [], tags: [])
            existing.feeds.append(feed)
            for tag in entry.tags where !existing.tags.contains(tag) {
                existing.tags.append(tag)
            }
            byAuthor[authorName] = existing
        }

        let connections = byAuthor.map { name, data in
            ImportConnectionPreview(name: name, feeds: data.feeds, tags: data.tags)
        }.sorted { $0.name < $1.name }

        return .success(ImportPreview(connections: connections, errors: errors))
    }

    /// Confirm import: create connections, feeds, and tags in SwiftData.
    static func confirm(
        connections: [ImportConnectionPreview],
        context: ModelContext
    ) -> ImportResult {
        var createdConnections = 0
        var createdFeeds = 0
        var createdTags = 0

        for connectionPreview in connections {
            let connection = ConnectionStore.create(
                in: context,
                name: connectionPreview.name
            )
            createdConnections += 1

            // Create feeds
            for feedPreview in connectionPreview.feeds {
                _ = FeedStore.create(
                    in: context,
                    connection: connection,
                    url: feedPreview.url,
                    title: feedPreview.title
                )
                createdFeeds += 1
            }

            // Create and associate tags
            for tagName in connectionPreview.tags {
                let tag = TagStore.getOrCreate(in: context, name: tagName)
                TagStore.addToConnection(tag, connection: connection)
                createdTags += 1
            }
        }

        try? context.save()
        logger.info("Import complete: \(createdConnections) connections, \(createdFeeds) feeds, \(createdTags) tags")

        return ImportResult(
            createdConnections: createdConnections,
            createdFeeds: createdFeeds,
            createdTags: createdTags
        )
    }
}
