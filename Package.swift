// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PostureRoutineKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PostureRoutineKit", targets: ["PostureRoutineKit"]),
    ],
    targets: [
        .target(name: "PostureRoutineKit"),
        .testTarget(name: "PostureRoutineKitTests", dependencies: ["PostureRoutineKit"]),
    ]
)
