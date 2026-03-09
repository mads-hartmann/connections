import Foundation
import SwiftSoup
import os

/// Discovered feed from a web page's <link rel="alternate"> tags.
struct DiscoveredFeedInfo: Hashable {
    let url: String
    let title: String?
    let format: String // "rss", "atom", "json_feed"
}

/// A classified social profile URL.
struct ClassifiedProfileInfo: Hashable {
    let url: String
    let fieldType: CDMetadataFieldType
}

/// Contact metadata discovered from a web page.
struct DiscoveredContactMetadata {
    let name: String?
    let photo: String?
    let feeds: [DiscoveredFeedInfo]
    let socialProfiles: [ClassifiedProfileInfo]
}

struct ContactDiscoveryError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Discovers contact metadata (feeds, social profiles) from a web page.
enum ContactDiscoveryService {

    private static let logger = Logger(subsystem: "Connections", category: "ContactDiscovery")

    /// Fetch a URL and extract contact metadata.
    static func discover(url: String) async -> Result<DiscoveredContactMetadata, ContactDiscoveryError> {
        guard let pageURL = URL(string: url) else {
            return .failure(ContactDiscoveryError(message: "Invalid URL"))
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: pageURL)
            guard let html = String(data: data, encoding: .utf8) else {
                return .failure(ContactDiscoveryError(message: "Failed to decode HTML"))
            }

            let result = extract(url: url, html: html)
            return .success(result)
        } catch {
            return .failure(ContactDiscoveryError(message: error.localizedDescription))
        }
    }

    /// Extract contact metadata from HTML.
    static func extract(url: String, html: String) -> DiscoveredContactMetadata {
        let baseURL = URL(string: url)

        do {
            let doc = try SwiftSoup.parse(html, url)

            let feeds = extractFeeds(doc: doc, baseURL: baseURL)
            let name = extractName(doc: doc)
            let photo = extractPhoto(doc: doc, baseURL: baseURL)
            let socialProfiles = extractAndClassifyProfiles(doc: doc, baseURL: baseURL)

            return DiscoveredContactMetadata(
                name: name,
                photo: photo,
                feeds: feeds,
                socialProfiles: socialProfiles
            )
        } catch {
            logger.error("Failed to parse HTML: \(error.localizedDescription)")
            return DiscoveredContactMetadata(name: nil, photo: nil, feeds: [], socialProfiles: [])
        }
    }

    // MARK: - Feed Discovery

    private static func extractFeeds(doc: Document, baseURL: URL?) -> [DiscoveredFeedInfo] {
        do {
            let links = try doc.select("link[rel=alternate]")
            return links.compactMap { link -> DiscoveredFeedInfo? in
                guard let typeAttr = try? link.attr("type"),
                      let href = try? link.attr("href"),
                      !href.isEmpty else { return nil }

                let format: String?
                switch typeAttr.lowercased() {
                case "application/rss+xml": format = "rss"
                case "application/atom+xml": format = "atom"
                case "application/feed+json", "application/json": format = "json_feed"
                default: format = nil
                }

                guard let format else { return nil }

                let resolvedUrl = resolveURL(href, base: baseURL)
                let title = try? link.attr("title")

                return DiscoveredFeedInfo(
                    url: resolvedUrl,
                    title: title?.isEmpty == true ? nil : title,
                    format: format
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Name Extraction

    private static func extractName(doc: Document) -> String? {
        // Try common patterns: h-card, meta author, title
        if let hCardName = try? doc.select(".h-card .p-name, [class*=h-card] .p-name").first()?.text(),
           !hCardName.isEmpty {
            return hCardName
        }
        if let metaAuthor = try? doc.select("meta[name=author]").first()?.attr("content"),
           !metaAuthor.isEmpty {
            return metaAuthor
        }
        return nil
    }

    // MARK: - Photo Extraction

    private static func extractPhoto(doc: Document, baseURL: URL?) -> String? {
        // Try h-card photo
        if let hCardPhoto = try? doc.select(".h-card .u-photo, [class*=h-card] img").first()?.attr("src"),
           !hCardPhoto.isEmpty {
            return resolveURL(hCardPhoto, base: baseURL)
        }
        // Try favicon as fallback
        if let favicon = try? doc.select("link[rel~=icon]").first()?.attr("href"),
           !favicon.isEmpty {
            return resolveURL(favicon, base: baseURL)
        }
        return nil
    }

    // MARK: - Social Profile Classification

    private static func extractAndClassifyProfiles(doc: Document, baseURL: URL?) -> [ClassifiedProfileInfo] {
        var profiles: [ClassifiedProfileInfo] = []
        var seen = Set<String>()

        // Extract rel=me links
        if let relMeLinks = try? doc.select("a[rel~=me]") {
            for link in relMeLinks {
                guard let href = try? link.attr("href"), !href.isEmpty else { continue }
                let resolved = resolveURL(href, base: baseURL)
                guard !seen.contains(resolved) else { continue }
                seen.insert(resolved)

                let fieldType = classifyURL(resolved)
                profiles.append(ClassifiedProfileInfo(url: resolved, fieldType: fieldType))
            }
        }

        return profiles
    }

    /// Classify a URL into a metadata field type based on its domain.
    static func classifyURL(_ url: String) -> CDMetadataFieldType {
        if url.lowercased().hasPrefix("mailto:") {
            return .email
        }

        guard let host = URL(string: url)?.host?.lowercased() else {
            return .other
        }

        if hostMatches(host, domain: "twitter.com") || hostMatches(host, domain: "x.com") {
            return .x
        } else if hostMatches(host, domain: "github.com") {
            return .gitHub
        } else if hostMatches(host, domain: "linkedin.com") {
            return .linkedIn
        } else if hostMatches(host, domain: "bsky.app") || hostMatches(host, domain: "bsky.social") {
            return .bluesky
        } else if hostMatches(host, domain: "youtube.com") {
            return .youTube
        } else if hostMatches(host, domain: "mastodon.social")
                    || hostMatches(host, domain: "mastodon.online")
                    || hostMatches(host, domain: "fosstodon.org")
                    || hostMatches(host, domain: "hachyderm.io") {
            return .mastodon
        }

        return .other
    }

    private static func hostMatches(_ host: String, domain: String) -> Bool {
        host == domain || host.hasSuffix(".\(domain)")
    }

    private static func resolveURL(_ href: String, base: URL?) -> String {
        if href.hasPrefix("http://") || href.hasPrefix("https://") || href.hasPrefix("mailto:") {
            return href
        }
        guard let base else { return href }
        return URL(string: href, relativeTo: base)?.absoluteString ?? href
    }
}
