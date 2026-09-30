// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kello",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
        .package(url: "https://github.com/gabry-ts/partiti-ui", from: "0.3.0"),
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
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "PartitiUI", package: "partiti-ui"),
            ],
            path: "Sources/Kello",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KelloCoreTests",
            dependencies: ["KelloCore"],
            path: "Tests/KelloCoreTests"
        ),
    ]
)
