import Foundation
import FeedKit

/// A single item extracted from an RSS/Atom feed.
struct ParsedFeedItem {
    let title: String?
    let url: String?
    let content: String?
    let author: String?
    let publishedAt: Date?
    let imageUrl: String?
    let categories: [String]
}

/// Metadata extracted from a feed (author, title).
struct FeedMetadata {
    let author: String?
    let title: String?
}

enum FeedParserService {

    /// Parse feed data and extract metadata (author, title).
    static func extractMetadata(from data: Data) -> FeedMetadata? {
        let parser = FeedKit.FeedParser(data: data)
        let result = parser.parse()

        switch result {
        case .success(let feed):
            switch feed {
            case .rss(let rssFeed):
                let author = rssFeed.managingEditor ?? rssFeed.items?.first?.author
                return FeedMetadata(author: author, title: rssFeed.title)
            case .atom(let atomFeed):
                let author = atomFeed.authors?.first?.name ?? atomFeed.entries?.first?.authors?.first?.name
                return FeedMetadata(author: author, title: atomFeed.title)
            case .json(let jsonFeed):
                let author = jsonFeed.author?.name
                return FeedMetadata(author: author, title: jsonFeed.title)
            }
        case .failure:
            return nil
        }
    }

    /// Parse feed data and extract all items.
    static func parseItems(from data: Data) -> [ParsedFeedItem] {
        let parser = FeedKit.FeedParser(data: data)
        let result = parser.parse()

        switch result {
        case .success(let feed):
            switch feed {
            case .rss(let rssFeed):
                return (rssFeed.items ?? []).compactMap(rssItemToParsed)
            case .atom(let atomFeed):
                return (atomFeed.entries ?? []).compactMap(atomEntryToParsed)
            case .json(let jsonFeed):
                return (jsonFeed.items ?? []).compactMap(jsonItemToParsed)
            }
        case .failure:
            return []
        }
    }

    /// Fetch a feed URL and extract metadata.
    static func fetchMetadata(url: String) async -> FeedMetadata? {
        guard let feedURL = URL(string: url) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: feedURL)
            return extractMetadata(from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private static func rssItemToParsed(_ item: RSSFeedItem) -> ParsedFeedItem? {
        let url = item.link ?? item.guid?.value
        guard let url else { return nil }

        let imageUrl = item.enclosure.flatMap { enc -> String? in
            guard let mime = enc.attributes?.type, mime.hasPrefix("image/") else { return nil }
            return enc.attributes?.url
        }

        return ParsedFeedItem(
            title: item.title,
            url: url,
            content: item.description,
            author: item.author,
            publishedAt: item.pubDate,
            imageUrl: imageUrl,
            categories: item.categories?.compactMap(\.value) ?? []
        )
    }

    private static func atomEntryToParsed(_ entry: AtomFeedEntry) -> ParsedFeedItem? {
        let alternateLink = entry.links?.first { $0.attributes?.rel == "alternate" }
        let url = alternateLink?.attributes?.href
            ?? entry.links?.first?.attributes?.href
            ?? entry.id

        guard let url else { return nil }

        let content = entry.content?.value ?? entry.summary?.value
        let author = entry.authors?.first?.name

        let imageUrl = entry.links?.first { link in
            link.attributes?.type?.hasPrefix("image/") ?? false
        }?.attributes?.href

        let publishedAt = entry.published ?? entry.updated

        return ParsedFeedItem(
            title: entry.title,
            url: url,
            content: content,
            author: author,
            publishedAt: publishedAt,
            imageUrl: imageUrl,
            categories: entry.categories?.compactMap { $0.attributes?.label ?? $0.attributes?.term } ?? []
        )
    }

    private static func jsonItemToParsed(_ item: JSONFeedItem) -> ParsedFeedItem? {
        guard let url = item.url ?? item.externalUrl ?? item.id else { return nil }

        return ParsedFeedItem(
            title: item.title,
            url: url,
            content: item.contentHtml ?? item.contentText ?? item.summary,
            author: item.author?.name,
            publishedAt: item.datePublished,
            imageUrl: item.image ?? item.bannerImage,
            categories: item.tags ?? []
        )
    }
}
