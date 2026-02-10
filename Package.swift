// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MungMung",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MungMung", targets: ["MungMung"])
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
        )
    ]
)
