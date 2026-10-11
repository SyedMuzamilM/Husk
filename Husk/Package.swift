// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HuskCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "HuskCore", targets: ["HuskCore"])],
    targets: [
        .target(
            name: "HuskCore", path: "Husk",
            exclude: ["Assets.xcassets", "Views", "ContentView.swift", "HuskApp.swift"],
            sources: ["Models", "Services", "Theme"]
        ),
        .testTarget(name: "HuskCoreTests", dependencies: ["HuskCore"], path: "Tests/HuskCoreTests")
    ],
    swiftLanguageModes: [.v6]
)
