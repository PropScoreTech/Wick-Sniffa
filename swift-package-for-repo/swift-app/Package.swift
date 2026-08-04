// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SirDarbsSniffCounter",
    platforms: [.macOS(.v11)],
    targets: [
        .executableTarget(
            name: "SirDarbsSniffCounter",
            path: "Sources/SirDarbsSniffCounter"
        )
    ]
)
