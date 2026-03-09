import Foundation
import LinkPresentation
import SwiftData
import os

/// Fetches URL metadata using Apple's LinkPresentation framework.
enum UrlMetadataService {

    private static let logger = Logger(subsystem: "Connections", category: "UrlMetadata")

    /// Fetch metadata for a single URL using LPMetadataProvider.
    static func fetchMetadata(for url: String) async -> LinkMetadataResult? {
        guard let linkURL = URL(string: url) else { return nil }

        let provider = LPMetadataProvider()
        do {
            let metadata = try await provider.startFetchingMetadata(for: linkURL)
            return LinkMetadataResult(
                title: metadata.title,
                description: nil, // LPMetadataProvider doesn't expose description directly
                image: metadata.imageProvider != nil ? url : nil,
                siteName: nil // Not directly available
            )
        } catch {
            logger.warning("Failed to fetch metadata for \(url): \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetch and apply metadata to a CDUri.
    static func fetchAndApply(to uri: CDUri) async {
        guard let linkURL = URL(string: uri.url) else {
            uri.ogFetchError = "Invalid URL"
            uri.ogFetchedAt = Date()
            return
        }

        let provider = LPMetadataProvider()
        do {
            let metadata = try await provider.startFetchingMetadata(for: linkURL)
            uri.ogTitle = metadata.title
            uri.ogSiteName = metadata.url?.host
            uri.ogFetchedAt = Date()
            uri.ogFetchError = nil

            // Extract image URL if available
            if let imageProvider = metadata.imageProvider {
                // LPMetadataProvider gives us an NSItemProvider, not a URL.
                // We store the original URL's og:image via the metadata title for now.
                // For a richer approach, we could load the image data.
                _ = imageProvider // Acknowledge but don't block on image loading
            }
        } catch {
            uri.ogFetchError = error.localizedDescription
            uri.ogFetchedAt = Date()
        }
    }

    /// Batch-process URIs that need metadata.
    static func fetchMetadataForPending(context: ModelContext) async {
        let uris = UriStore.listNeedingMetadata(in: context)
        guard !uris.isEmpty else { return }

        logger.info("Fetching metadata for \(uris.count) URIs")

        for uri in uris {
            await fetchAndApply(to: uri)
        }

        try? context.save()
        logger.info("Metadata fetch complete")
    }
}

struct LinkMetadataResult {
    let title: String?
    let description: String?
    let image: String?
    let siteName: String?
}
