// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MungMung",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MungMung", targets: ["MungMung"]),
        .executable(name: "MungGhosttyFocus", targets: ["MungGhosttyFocus"])
    ],
    targets: [
        .executableTarget(
            name: "MungMung",
            path: "Sources/MungMung",
            resources: [
                .copy("../../Resources/Info.plist")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "MungGhosttyFocus",
            path: "Sources/MungGhosttyFocus"
        ),
        .testTarget(
            name: "MungMungTests",
            dependencies: ["MungMung"],
            path: "Tests/MungMungTests"
        )
    ]
)
