// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AMaps",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "AMapsDomain", targets: ["AMapsDomain"]),
        .library(name: "AMapsFog", targets: ["AMapsFog"]),
        .library(name: "AMapsTracking", targets: ["AMapsTracking"]),
        .library(name: "AMapsStorage", targets: ["AMapsStorage"]),
        .library(name: "AMapsApp", targets: ["AMapsApp"]),
    ],
    targets: [
        .target(name: "AMapsDomain"),
        .target(name: "AMapsFog", dependencies: ["AMapsDomain"]),
        .target(name: "AMapsTracking", dependencies: ["AMapsDomain", "AMapsFog"]),
        .target(name: "AMapsStorage", dependencies: ["AMapsDomain"]),
        .target(name: "AMapsApp", dependencies: [
            "AMapsDomain", "AMapsFog", "AMapsTracking", "AMapsStorage",
        ]),
        .testTarget(name: "AMapsTests", dependencies: ["AMapsDomain", "AMapsFog", "AMapsTracking"]),
    ]
)
