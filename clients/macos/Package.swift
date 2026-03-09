// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Connections",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/nmdias/FeedKit.git", from: "9.1.2"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "Connections",
            dependencies: ["FeedKit", "SwiftSoup"],
            path: "Connections"
        ),
    ]
)
