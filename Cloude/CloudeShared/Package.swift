// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CloudeShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CloudeShared",
            targets: ["CloudeShared"]
        ),
    ],
    targets: [
        .target(
            name: "CloudeShared"
        ),
    ]
)
