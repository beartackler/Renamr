// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Renamr",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RenamrCore", targets: ["RenamrCore"]),
        .executable(name: "renamr", targets: ["renamr"]),
        .executable(name: "RenamrApp", targets: ["RenamrApp"]),
    ],
    targets: [
        // The moat: a pure-Swift programming-by-example synthesizer for filenames.
        // No UI, no platform deps beyond Foundation — fully unit-testable headless.
        .target(name: "RenamrCore"),
        // A thin CLI that exercises the engine (and doubles as the power-user companion).
        .executableTarget(name: "renamr", dependencies: ["RenamrCore"]),
        // The SwiftUI app: drop a folder, rename one file, the rest follow.
        .executableTarget(name: "RenamrApp", dependencies: ["RenamrCore"]),
        .testTarget(name: "RenamrCoreTests", dependencies: ["RenamrCore"]),
    ]
)
