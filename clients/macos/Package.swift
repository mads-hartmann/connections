// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Connections",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Connections",
            path: "Connections"
        ),
    ]
)
