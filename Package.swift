// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CalendarOverlay",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "CalendarOverlay",
            path: "Sources",
            exclude: ["CalendarOverlayApp.swift"]
        ),
        .testTarget(
            name: "CalendarOverlayTests",
            dependencies: ["CalendarOverlay"],
            path: "Tests"
        ),
    ]
)
