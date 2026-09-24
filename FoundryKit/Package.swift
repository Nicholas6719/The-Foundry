// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FoundryKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "FoundryCore", targets: ["FoundryCore"])
    ],
    targets: [
        .target(name: "FoundryCore"),
        .testTarget(name: "FoundryCoreTests", dependencies: ["FoundryCore"])
    ],
    swiftLanguageModes: [.v6]
)
