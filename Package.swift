// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Perch",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Perch", targets: ["Perch"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")],
    targets: [
        .target(name: "PerchCore"),
        .executableTarget(name: "Perch", dependencies: ["PerchCore", .product(name: "Sparkle", package: "Sparkle")], swiftSettings: [.swiftLanguageMode(.v5)], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "PerchCoreTests", dependencies: ["PerchCore"]),
        .testTarget(name: "PerchAppTests", dependencies: ["Perch"], swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
