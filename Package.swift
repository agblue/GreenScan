// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "GreenScanCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "GreenScanCore", targets: ["GreenScanCore"])],
    targets: [
        .target(name: "GreenScanCore", path: "GreenScan/Core"),
        .testTarget(name: "GreenScanCoreTests", dependencies: ["GreenScanCore"], path: "Tests")
    ]
)
