// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Murmur",
    platforms: [
        // macOS 14 is the floor because FluidAudio (Parakeet via Core ML)
        // requires it. SwiftPM will not link a macOS-14 package into a
        // macOS-13 target, so adding Parakeet forces the bump. whisper.cpp
        // remains available as the fallback engine for unsupported languages.
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Murmur", targets: ["Murmur"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.1")
    ],
    targets: [
        .executableTarget(
            name: "Murmur",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
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
