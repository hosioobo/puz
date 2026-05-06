// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pause",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PauseCore", targets: ["PauseCore"]),
        .executable(name: "PauseCoreTestRunner", targets: ["PauseCoreTestRunner"]),
        .executable(name: "PauseApp", targets: ["PauseApp"])
    ],
    targets: [
        .target(name: "PauseCore"),
        .executableTarget(name: "PauseCoreTestRunner", dependencies: ["PauseCore"]),
        .executableTarget(name: "PauseApp", dependencies: ["PauseCore"])
    ]
)
