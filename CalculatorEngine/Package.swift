// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CalculatorEngine",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "CalculatorEngine", targets: ["CalculatorEngine"]),
    ],
    targets: [
        .target(name: "CalculatorEngine", path: "Sources"),
        .testTarget(
            name: "CalculatorEngineTests",
            dependencies: ["CalculatorEngine"],
            path: "Tests/CalculatorEngineTests"
        ),
    ]
)
