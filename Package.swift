// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ClaudeUsageBar",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "ClaudeUsageBar", targets: ["ClaudeUsageBar"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeUsageBar",
            dependencies: [
                "SwiftTerm",
            ],
            path: "Sources/ClaudeUsageBar"
        ),
        .testTarget(
            name: "ClaudeUsageBarTests",
            dependencies: [
                "ClaudeUsageBar",
                "SwiftTerm",
            ],
            path: "Tests/ClaudeUsageBarTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
