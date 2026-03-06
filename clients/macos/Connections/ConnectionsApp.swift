import SwiftUI

@main
struct ConnectionsApp: App {
    @FocusedValue(\.sidebarSelection) var selection
    @FocusedValue(\.sidebarVisibility) var sidebarVisibility

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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

        Settings {
            SettingsView()
        }
    }
}
