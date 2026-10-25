// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "F4",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "F4", targets: ["F4"])
    ],
    targets: [
        // Pure logic (file types, search, grid navigation), no AppKit: unit-tested in CI.
        .target(name: "F4Core", path: "Sources/F4Core"),
        // The panel app: AppKit for the window and the system, SwiftUI for the content.
        .executableTarget(
            name: "F4",
            dependencies: ["F4Core"],
            path: "Sources/F4"
        ),
        .testTarget(
            name: "F4CoreTests",
            dependencies: ["F4Core"],
            path: "Tests/F4CoreTests"
        ),
    ]
)
