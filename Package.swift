// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "QRScannerKit",
    platforms: [
        .iOS(.v17),
        // The camera views are iOS only. macOS 14 builds the parsing, filtering, geometry and photo
        // scanning core so `swift test` runs on a Mac.
        .macOS(.v14),
    ],
    products: [
        .library(name: "QRScannerKit", targets: ["QRScannerKit"]),
    ],
    targets: [
        .target(name: "QRScannerKit"),
        .testTarget(name: "QRScannerKitTests", dependencies: ["QRScannerKit"]),
    ]
)
