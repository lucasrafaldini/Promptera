// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "promptera",
    defaultLocalization: "pt",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PrompteraApp", targets: ["PrompteraApp"]),
        .executable(name: "promptera", targets: ["PrompteraCLI"]),
        .library(name: "PrompteraKit", targets: ["PrompteraKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1")
    ],
    targets: [
        .target(
            name: "PrompteraKit",
            dependencies: [],
            path: "Sources/PrompteraKit",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "PrompteraCLI",
            dependencies: ["PrompteraKit"],
            path: "Sources/PrompteraCLI"
        ),
        .executableTarget(
            name: "PrompteraApp",
            dependencies: [
                "PrompteraKit",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/PrompteraApp"
        ),
        .testTarget(
            name: "PrompteraKitTests",
            dependencies: ["PrompteraKit"],
            path: "Tests/PrompteraKitTests"
        )
    ]
)
