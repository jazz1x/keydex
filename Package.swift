// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Keydex",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(name: "KeydexCore", targets: ["KeydexCore"]),
    .library(name: "KeydexKeychain", targets: ["KeydexKeychain"]),
    .library(name: "KeydexSources", targets: ["KeydexSources"]),
    .library(name: "KeydexStore", targets: ["KeydexStore"]),
    .executable(name: "keydex", targets: ["keydex"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
  ],
  targets: [
    .target(name: "KeydexCore"),
    .target(
      name: "KeydexKeychain",
      dependencies: ["KeydexCore"],
      linkerSettings: [.linkedFramework("Security")]
    ),
    .target(name: "KeydexSources", dependencies: ["KeydexCore"]),
    .target(name: "KeydexStore", dependencies: ["KeydexCore"]),
    .executableTarget(
      name: "keydex",
      dependencies: [
        "KeydexCore",
        "KeydexKeychain",
        "KeydexSources",
        "KeydexStore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(name: "KeydexCoreTests", dependencies: ["KeydexCore"]),
    .testTarget(name: "KeydexSourcesTests", dependencies: ["KeydexSources"]),
    .testTarget(name: "KeydexStoreTests", dependencies: ["KeydexStore"]),
  ]
)
