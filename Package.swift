// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EpochBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "EpochBar",
            path: "Sources/EpochBar"
        ),
        .testTarget(
            name: "EpochBarTests",
            dependencies: ["EpochBar"],
            path: "Tests/EpochBarTests"
        )
    ]
)
