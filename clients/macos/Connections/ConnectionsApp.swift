import SwiftUI

@main
struct ConnectionsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1000, height: 700)

        Settings {
            SettingsView()
        }
    }
}
