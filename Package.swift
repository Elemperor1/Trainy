// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Trainy",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .library(
            name: "TrainyCore",
            targets: ["TrainyCore"]
        )
    ],
    targets: [
        .target(
            name: "TrainyCore",
            path: "Sources/TrainyCore",
            linkerSettings: [
                .linkedFramework("MapKit", .when(platforms: [.iOS])),
                .linkedFramework("SwiftUI", .when(platforms: [.iOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(
            name: "TrainyCoreTests",
            dependencies: ["TrainyCore"],
            path: "Tests/TrainyCoreTests"
        )
    ]
)
