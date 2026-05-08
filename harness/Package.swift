// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VortexHarness",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../../piston")
    ],
    targets: [
        .executableTarget(
            name: "VortexHarness",
            dependencies: [
                .product(name: "Piston", package: "Piston")
            ]
        )
    ]
)
