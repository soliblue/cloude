// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CloudeAndroidBridge",
    products: [
        .library(
            name: "CloudeAndroidBridge",
            type: .dynamic,
            targets: ["CloudeAndroidBridge"]
        ),
    ],
    dependencies: [
        .package(path: "../CloudeShared"),
    ],
    targets: [
        .target(
            name: "CloudeAndroidBridge",
            dependencies: ["CloudeShared"]
        ),
    ]
)
