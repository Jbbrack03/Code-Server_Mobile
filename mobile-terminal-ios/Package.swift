// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MobileTerminal",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MobileTerminal",
            targets: ["MobileTerminal"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.1"),
        .package(url: "https://github.com/daltoniam/Starscream", from: "4.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),
    ],
    targets: [
        .target(
            name: "MobileTerminal",
            dependencies: [
                "SwiftTerm",
                "Starscream",
                "KeychainAccess"
            ]
        ),
        .testTarget(
            name: "MobileTerminalTests",
            dependencies: ["MobileTerminal"]
        ),
    ]
)