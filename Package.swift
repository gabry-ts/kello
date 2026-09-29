// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kello",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
    ],
    targets: [
        .target(
            name: "KelloCore",
            path: "Sources/KelloCore"
        ),
        .executableTarget(
            name: "Kello",
            dependencies: [
                "KelloCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
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
