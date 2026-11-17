// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClarityFeedbackKit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "ClarityFeedbackKit",
            targets: ["ClarityFeedbackKit"]
        )
    ],
    dependencies: [
        // Test-only: links tests written for a bug to their Clarity issue.
        .package(url: "https://github.com/pdarcey/ClarityLinks", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "ClarityFeedbackKit"
        ),
        .testTarget(
            name: "ClarityFeedbackKitTests",
            dependencies: [
                "ClarityFeedbackKit",
                .product(name: "ClarityTesting", package: "ClarityLinks")
            ]
        )
    ]
)
