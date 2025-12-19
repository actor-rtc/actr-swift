// swift-tools-version: 6.2
import Foundation
import PackageDescription

// Binary distribution:
// - Default: fetch ActrFFI.xcframework from GitHub Release.
// - Local override: set ACTR_BINARY_PATH to a local xcframework path when developing.
let env = ProcessInfo.processInfo.environment
let localBinaryPath = env["ACTR_BINARY_PATH"]

let releaseTag = env["ACTR_BINARY_TAG"] ?? "v0.1.0"
let remoteBinaryURL = "https://github.com/actor-rtc/actr-swift/releases/download/\(releaseTag)/ActrFFI.xcframework.zip"
let remoteBinaryChecksum = env["ACTR_BINARY_CHECKSUM"] ?? "20c43298f21d166e30a0d5cfe49d3e8aed7151414c61d023d6e97ce3caf8ce36"

let actrBinaryTarget: Target
if let localBinaryPath {
    actrBinaryTarget = .binaryTarget(
        name: "ActrFFI",
        path: localBinaryPath
    )
} else {
    actrBinaryTarget = .binaryTarget(
        name: "ActrFFI",
        url: remoteBinaryURL,
        checksum: remoteBinaryChecksum
    )
}

let package = Package(
    name: "actr-swift",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "ActrSwift",
            targets: ["ActrSwift"]
        ),
    ],
    targets: [
        actrBinaryTarget,
        .target(
            name: "actrFFI",
            path: "ActrBindings",
            sources: ["actrFFI.c"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "ActrSwift",
            dependencies: ["actrFFI", "ActrFFI"],
            path: "ActrBindings",
            exclude: [
                "include",
                "actrFFI.c",
                "actrFFI.modulemap",
            ],
            sources: ["Actr.swift"]
        ),
    ]
)
