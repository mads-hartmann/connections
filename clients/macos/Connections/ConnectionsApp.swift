import SwiftUI
import SwiftData

@main
struct ConnectionsApp: App {
    @FocusedValue(\.sidebarSelection) var selection
    @FocusedValue(\.sidebarVisibility) var sidebarVisibility

    let feedSyncService = FeedSyncService()
    @State private var backgroundSyncManager: BackgroundSyncManager?

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CDConnection.self,
            CDTag.self,
            CDFeed.self,
            CDUri.self,
            CDConnectionMetadata.self,
        ])
        // Use .none for local-only storage. Switch to .automatic when
        // the app is signed with a CloudKit entitlement for iCloud sync.
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(feedSyncService)
                .onAppear {
                    startBackgroundSync()
                }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    guard let binding = sidebarVisibility else { return }
                    withAnimation {
                        binding.wrappedValue = binding.wrappedValue == .detailOnly
                            ? .all
                            : .detailOnly
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }

            CommandMenu("Go") {
                Button("Unread") {
                    selection?.wrappedValue = .uriFilter(.unread)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Read Later") {
                    selection?.wrappedValue = .uriFilter(.readLater)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Upvoted") {
                    selection?.wrappedValue = .uriFilter(.upvoted)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Inbox") {
                    selection?.wrappedValue = .uriFilter(.inbox)
                }
                .keyboardShortcut("4", modifiers: .command)
            }
        }
    }

    @MainActor
    private func startBackgroundSync() {
        guard backgroundSyncManager == nil else { return }
        let manager = BackgroundSyncManager(feedSyncService: feedSyncService)
        backgroundSyncManager = manager
        let context = sharedModelContainer.mainContext
        manager.start(context: context)
    }
}
