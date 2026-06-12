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
        .package(url: "https://github.com/awareframework/com.awareframework.ios.core.git", from: "1.3.0")
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
