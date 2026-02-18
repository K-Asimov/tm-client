// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TMClient",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "TMClientApp", targets: ["TMClientApp"]),
        .library(name: "TMCore", targets: ["TMCore"])
    ],
    targets: [
        .target(name: "TMCore"),
        .executableTarget(
            name: "TMClientApp",
            dependencies: ["TMCore"],
            resources: [.process("Resources")]
        )
    ]
)
