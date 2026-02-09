// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KokoroReplay",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: "../../build/SourcePackages/checkouts/kokoro-ios")
    ],
    targets: [
        .executableTarget(
            name: "KokoroReplay",
            dependencies: [
                .product(name: "KokoroSwift", package: "kokoro-ios")
            ]
        )
    ]
)
