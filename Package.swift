// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "bbc-news-meetings",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "bbc-news-meetings",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/BBCNewsMeetings",
            resources: [
                .copy("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("EventKit"),
            ]
        ),
    ]
)
