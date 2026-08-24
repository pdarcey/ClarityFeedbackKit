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
    targets: [
        .target(
            name: "ClarityFeedbackKit"
        ),
        .testTarget(
            name: "ClarityFeedbackKitTests",
            dependencies: ["ClarityFeedbackKit"]
        )
    ]
)
