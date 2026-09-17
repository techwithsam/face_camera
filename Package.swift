// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// To learn more about a Swift Package, see https://developer.apple.com/documentation/xcode/creating_a_standalone_swift_package_with_xcode

import PackageDescription

let package = Package(
    name: "face_camera",
    platforms: [
        .iOS("16.0"),
    ],
    products: [
        // A library exposing the plugin to Xcode / FlutterPluginRegistrant.
        .library(name: "face-camera", targets: ["face_camera"]),
    ],
    targets: [
        .target(
            name: "face_camera",
            dependencies: [],
            path: "ios/Classes",
            // Expose ObjC headers so the Swift ↔ ObjC bridge (face_camera-Swift.h) works.
            publicHeadersPath: "."
        ),
    ]
)
