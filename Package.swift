// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.applogger",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.applogger",
            targets: [
                "com.awareframework.ios.sensor.applogger"
            ]
        ),
    ],
    dependencies: [
        .package(path: "../com.awareframework.ios.core")
    ],
    targets: [
        .target(
            name: "com.awareframework.ios.sensor.applogger",
            dependencies: [
                .product(
                    name: "com.awareframework.ios.core",
                    package: "com.awareframework.ios.core",
                    condition: .when(platforms: [.iOS])
                )
            ],
            path: "Sources/com.awareframework.ios.sensor.applogger"
        ),
    ],
    swiftLanguageModes: [.v5]
)
