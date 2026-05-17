// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Murmur",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Murmur", targets: ["Murmur"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Murmur",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Murmur",
            resources: [
                .copy("Resources/model-manifest.json")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MurmurTests",
            dependencies: ["Murmur"],
            path: "Tests/MurmurTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
