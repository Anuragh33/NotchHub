// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchHub",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "NotchHub", targets: ["NotchHub"])
    ],
    targets: [
        .executableTarget(
            name: "NotchHub",
            path: "Sources/NotchHub",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Combine"),
                .linkedFramework("UniformTypeIdentifiers"),
                .linkedFramework("WebKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("IOKit"),
                .linkedFramework("IOBluetooth"),
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
