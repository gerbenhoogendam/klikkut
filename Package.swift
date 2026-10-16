// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Muisklikkert",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Muisklikkert",
            path: "Sources/Muisklikkert"
        )
    ],
    swiftLanguageModes: [.v5]
)
