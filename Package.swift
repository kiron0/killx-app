// swift-tools-version: 5.9
import PackageDescription
import Foundation

let cltTestingFrameworkPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let needsCLTTestingSearchPath = FileManager.default.fileExists(
    atPath: cltTestingFrameworkPath + "/Testing.framework"
)

var testSwiftSettings: [SwiftSetting] = []
var testLinkerSettings: [LinkerSetting] = []

if needsCLTTestingSearchPath {
    testSwiftSettings = [
        .unsafeFlags(["-F", cltTestingFrameworkPath])
    ]
    testLinkerSettings = [
        .unsafeFlags([
            "-F", cltTestingFrameworkPath,
            "-framework", "Testing",
            "-Xlinker", "-rpath", "-Xlinker", cltTestingFrameworkPath,
            "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
        ])
    ]
}

let package = Package(
    name: "KillX",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "KillX", targets: ["KillX"]),
    ],
    targets: [
        .executableTarget(
            name: "KillX",
            path: "Sources/KillX"
        ),

        .testTarget(
            name: "KillXTests",
            dependencies: ["KillX"],
            path: "Tests/KillXTests",
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        ),
    ]
)
