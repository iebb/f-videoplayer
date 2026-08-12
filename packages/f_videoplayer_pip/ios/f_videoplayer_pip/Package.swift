// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "f_videoplayer_pip",
  platforms: [.iOS("12.0")],
  products: [
    .library(name: "f-videoplayer-pip", targets: ["f_videoplayer_pip"])
  ],
  targets: [
    .target(
      name: "f_videoplayer_pip",
      linkerSettings: [
        .linkedFramework("AVFoundation"),
        .linkedFramework("AVKit")
      ]
    )
  ]
)
