// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlowLite",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlowLite", targets: ["FlowLite"])
    ],
    targets: [
        .executableTarget(
            name: "FlowLite",
            path: "Sources/FlowLite"
        ),
        .testTarget(
            name: "FlowLiteTests",
            dependencies: ["FlowLite"],
            path: "Tests/FlowLiteTests"
        )
    ]
)
