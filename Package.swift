// swift-tools-version: 6.2
import Foundation
import PackageDescription

// Binary distribution:
// - Default: fetch ActrFFI.xcframework from GitHub Release.
// - Local override: set ACTR_BINARY_PATH to a local xcframework path when developing.
let env = ProcessInfo.processInfo.environment
let bindingsPath = env["ACTR_BINDINGS_PATH"] ?? "ActrBindings"
let overrideBinaryPath = env["ACTR_BINARY_PATH"]

let releaseTag = env["ACTR_BINARY_TAG"] ?? "v0.1.8"
let remoteBinaryURL = "https://github.com/actor-rtc/actr-swift/releases/download/\(releaseTag)/ActrFFI.xcframework.zip"
let remoteBinaryChecksum = env["ACTR_BINARY_CHECKSUM"] ?? "7f066fb43055bfe6533c1f750ea90864ca8be45b8264475d99deb1e26c17ae98"

let manifestDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let bundledBinaryPath = "ActrFFI.xcframework"
let bundledBinaryAbsolutePath = "\(manifestDir)/\(bundledBinaryPath)"

func binaryPathRelativeToPackageRoot(_ path: String) -> String? {
    if path.hasPrefix("/") {
        let prefix = manifestDir.hasSuffix("/") ? manifestDir : "\(manifestDir)/"
        guard path.hasPrefix(prefix) else { return nil }
        return String(path.dropFirst(prefix.count))
    }
    return path
}

let actrBinaryTarget: Target
if let overrideBinaryPath {
    if let relativeBinaryPath = binaryPathRelativeToPackageRoot(overrideBinaryPath) {
        actrBinaryTarget = .binaryTarget(
            name: "ActrFFI",
            path: relativeBinaryPath
        )
    } else {
        actrBinaryTarget = .binaryTarget(
            name: "ActrFFI",
            url: remoteBinaryURL,
            checksum: remoteBinaryChecksum
        )
    }
} else if FileManager.default.fileExists(atPath: bundledBinaryAbsolutePath) {
    actrBinaryTarget = .binaryTarget(
        name: "ActrFFI",
        path: bundledBinaryPath
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
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "ActrSwift",
            targets: ["ActrSwift"]
        ),
        .library(
            name: "Actr",
            targets: ["Actr"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.20.0"),
    ],
    targets: [
        actrBinaryTarget,
        .target(
            name: "actrFFI",
            path: bindingsPath,
            sources: ["actrFFI.c"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "ActrSwift",
            dependencies: ["actrFFI", "ActrFFI"],
            path: bindingsPath,
            exclude: [
                "include",
                "actrFFI.c",
            ],
            sources: ["Actr.swift"]
        ),
        .target(
            name: "Actr",
            dependencies: [
                "ActrSwift",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
    ]
)
