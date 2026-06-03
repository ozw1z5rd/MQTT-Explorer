// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MQTTExplorerBackend",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MQTTExplorerBackend",
            targets: ["MQTTExplorerBackend"]
        ),
        .executable(
            name: "MQTTExplorer",
            targets: ["MQTTExplorerApp"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/emqx/CocoaMQTT", from: "2.1.0"),
    ],
    targets: [
        .target(
            name: "MQTTExplorerBackend",
            dependencies: ["CocoaMQTT"],
            path: "Sources/MQTTExplorerBackend"
        ),
        .executableTarget(
            name: "MQTTExplorerApp",
            dependencies: ["MQTTExplorerBackend"],
            path: "Sources/MQTTExplorerApp"
        ),
        .testTarget(
            name: "MQTTExplorerBackendTests",
            dependencies: ["MQTTExplorerBackend"],
            path: "Tests/MQTTExplorerBackendTests"
        ),
    ]
)
