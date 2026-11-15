// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GrailkaufCore",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v15)],
    products: [.library(name: "GrailkaufCore", targets: ["GrailkaufCore"])],
    targets: [
        .target(name: "GrailkaufCore"),
        .testTarget(name: "GrailkaufCoreTests", dependencies: ["GrailkaufCore"]),
    ]
)
