// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "inversion",
  platforms: [
    .macOS(.v12)
  ],
  dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.5.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.1"),
  ],
  targets: [
    .executableTarget(
      name: "inversion",
      dependencies: [
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    )
  ]
)
