// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DownloadsOrganizer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "DownloadsOrganizer", path: "Sources/DownloadsOrganizer")
    ]
)
