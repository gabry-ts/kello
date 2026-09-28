// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kello",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "KelloCore",
            path: "Sources/KelloCore"
        ),
        .executableTarget(
            name: "Kello",
            dependencies: [
                "KelloCore",
            ],
            path: "Sources/Kello"
        ),
        .testTarget(
            name: "KelloCoreTests",
            dependencies: ["KelloCore"],
            path: "Tests/KelloCoreTests"
        ),
    ]
)
