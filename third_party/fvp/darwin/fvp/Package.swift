// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "fvp",
    platforms: [
        .iOS("12.0"),
        .macOS("10.13"),
    ],
    products: [
        // Dart resolves the C callback bridge with DynamicLibrary.process().
        // Keep this product dynamic so release archives embed the framework
        // and preserve its exported MdkCallbacks* symbols for dlsym.
        .library(name: "fvp", type: .dynamic, targets: ["fvp"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "fvp",
            dependencies: [
                .target(name: "mdk"),
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: ".",
            sources: [
                "Sources/fvp/FvpPlugin.mm",
                "Sources/fvp/callbacks.cpp",
            ],
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy"),
            ],
            publicHeadersPath: "Sources/fvp",
            cSettings: [
                .headerSearchPath("Sources/fvp"),
            ],
            cxxSettings: [
                .unsafeFlags(["-Wno-documentation"]),
            ],
            linkerSettings: [
                .linkedFramework("Flutter", .when(platforms: [.iOS])),
                .linkedFramework("FlutterMacOS", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Metal"),
            ]
        ),
        .binaryTarget(
            name: "mdk",
            url: "https://github.com/iebb/f-videoplayer/releases/download/mdk-nightly-2026-08-14/mdk.xcframework.zip",
            checksum: "615b9e8ddd6d31a35c109b8dcb2493e896a3b532aed0b6b498d1c62686fbe3b7"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
