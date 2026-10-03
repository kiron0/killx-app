// swift-tools-version: 5.9
import PackageDescription

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
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-F", "/Applications/Xcode_16.2.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_16.1.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_16.0.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_16.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_15.4.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-F", "/Applications/Xcode_16.2.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_16.1.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_16.0.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_16.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-F", "/Applications/Xcode_15.4.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-framework", "Testing"
                ])
            ]
        ),
    ]
)
