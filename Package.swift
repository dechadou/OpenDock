// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenDock",
    platforms: [
        .macOS("26.5")
    ],
    products: [
        .executable(name: "OpenDock", targets: ["OpenDock"]),
        .executable(name: "OpenDockDockRestorer", targets: ["OpenDockDockRestorer"]),
        .executable(name: "OpenDockUnitTests", targets: ["OpenDockUnitTests"]),
    ],
    targets: [
        .target(
            name: "OpenDockCore",
            path: "Sources/OpenDock"
        ),
        .executableTarget(
            name: "OpenDock",
            dependencies: ["OpenDockCore"],
            path: "Sources/OpenDockApp"
        ),
        .executableTarget(
            name: "OpenDockDockRestorer",
            dependencies: ["OpenDockCore"],
            path: "Sources/OpenDockDockRestorer"
        ),
        .executableTarget(
            name: "OpenDockUnitTests",
            dependencies: ["OpenDockCore"],
            path: "Tests/OpenDockUnitTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
