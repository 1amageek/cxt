// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "cxt",
    platforms: [.macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
//        .library(
//            name: "cxt",
//            targets: ["cxt"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", branch: "main"),
        .package(url: "https://github.com/1amageek/SwiftAgent.git", branch: "main")
    ],
    targets: [
        .executableTarget(name: "cxt",
                          dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "SwiftAgent", package: "SwiftAgent"),
            .product(name: "Agents", package: "SwiftAgent"),
            .product(name: "AgentTools", package: "SwiftAgent"),
        ]),
        .testTarget(
            name: "cxtTests",
            dependencies: ["cxt"]
        ),
    ]
)
