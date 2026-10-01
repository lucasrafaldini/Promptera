// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "promptera",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PrompteraApp", targets: ["PrompteraApp"]),
        .executable(name: "promptera", targets: ["PrompteraCLI"]),
        .library(name: "PrompteraKit", targets: ["PrompteraKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PrompteraKit",
            dependencies: [],
            path: "Sources/PrompteraKit"
        ),
        .executableTarget(
            name: "PrompteraCLI",
            dependencies: ["PrompteraKit"],
            path: "Sources/PrompteraCLI"
        ),
        .executableTarget(
            name: "PrompteraApp",
            dependencies: ["PrompteraKit"],
            path: "Sources/PrompteraApp"
        ),
        .testTarget(
            name: "PrompteraKitTests",
            dependencies: ["PrompteraKit"],
            path: "Tests/PrompteraKitTests"
        )
    ]
)
