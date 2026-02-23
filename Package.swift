// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "QuickTranslate",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "QuickTranslate",
            path: "Sources/QuickTranslate"
        )
    ]
)
