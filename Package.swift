// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "autoKSHelp",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "KSCore", path: "Sources/KSCore"),
        .executableTarget(name: "autoKSHelp", dependencies: ["KSCore"], path: "Sources/autoKSHelp"),
        .testTarget(name: "KSCoreTests", dependencies: ["KSCore"], path: "Tests/KSCoreTests"),
    ]
)
