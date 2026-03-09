import Foundation
import SwiftData
import os

/// Manages periodic feed sync and metadata fetching while the app is running.
/// On macOS, BGTaskScheduler is limited, so we use an in-app timer approach.
@MainActor
@Observable
final class BackgroundSyncManager {
    private let logger = Logger(subsystem: "Connections", category: "BackgroundSync")
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 3600 // 1 hour

    let feedSyncService: FeedSyncService

    init(feedSyncService: FeedSyncService) {
        self.feedSyncService = feedSyncService
    }

    /// Start the periodic sync timer. Call on app launch.
    func start(context: ModelContext) {
        logger.info("Starting background sync manager (interval: \(self.syncInterval)s)")

        // Initial sync on launch
        Task {
            await performSync(context: context)
        }

        // Schedule periodic sync on the main run loop
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.performSync(context: context)
            }
        }
    }

    /// Stop the periodic sync timer.
    func stop() {
        syncTimer?.invalidate()
        syncTimer = nil
        logger.info("Background sync manager stopped")
    }

    private func performSync(context: ModelContext) async {
        await feedSyncService.syncAllFeeds(context: context)
        await UrlMetadataService.fetchMetadataForPending(context: context)
    }
}
