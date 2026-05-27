// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocalSidebar",
    platforms: [
        .macOS("26.5")
    ],
    products: [
        .executable(name: "LocalSidebar", targets: ["LocalSidebar"]),
        .executable(name: "LocalSidebarDockRestorer", targets: ["LocalSidebarDockRestorer"]),
        .executable(name: "LocalSidebarUnitTests", targets: ["LocalSidebarUnitTests"]),
    ],
    targets: [
        .target(
            name: "LocalSidebarCore",
            path: "Sources/LocalSidebar"
        ),
        .executableTarget(
            name: "LocalSidebar",
            dependencies: ["LocalSidebarCore"],
            path: "Sources/LocalSidebarApp"
        ),
        .executableTarget(
            name: "LocalSidebarDockRestorer",
            dependencies: ["LocalSidebarCore"],
            path: "Sources/LocalSidebarDockRestorer"
        ),
        .executableTarget(
            name: "LocalSidebarUnitTests",
            dependencies: ["LocalSidebarCore"],
            path: "Tests/LocalSidebarUnitTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
