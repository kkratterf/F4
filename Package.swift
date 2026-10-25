// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ReactionDeck",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ReactionDeck", targets: ["ReactionDeck"])
    ],
    targets: [
        // Pure logic (file types, search, grid navigation), no AppKit: unit-tested in CI.
        .target(name: "ReactionDeckCore", path: "Sources/ReactionDeckCore"),
        // The panel app: AppKit for the window and the system, SwiftUI for the content.
        .executableTarget(
            name: "ReactionDeck",
            dependencies: ["ReactionDeckCore"],
            path: "Sources/ReactionDeck"
        ),
        .testTarget(
            name: "ReactionDeckCoreTests",
            dependencies: ["ReactionDeckCore"],
            path: "Tests/ReactionDeckCoreTests"
        ),
    ]
)
