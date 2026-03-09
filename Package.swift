// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "bos",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BosCore", targets: ["BosCore"]),
        .executable(name: "bos", targets: ["BosCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.2.4")
    ],
    targets: [
        .target(
            name: "BosCore",
            resources: [
                .copy("Resources/tma_plugin"),
                .copy("Resources/project_bootstrap")
            ]
        ),
        .executableTarget(
            name: "BosCLI",
            dependencies: [
                "BosCore",
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: [
                "BosCore",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
