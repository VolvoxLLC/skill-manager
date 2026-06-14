// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SkillDeckKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SkillDeckCore", targets: ["SkillDeckCore"]),
        .library(name: "SkillDeckSources", targets: ["SkillDeckSources"]),
        .library(name: "SkillDeckAgents", targets: ["SkillDeckAgents"]),
        .library(name: "SkillDeckPersistence", targets: ["SkillDeckPersistence"]),
        .library(name: "SkillDeckServices", targets: ["SkillDeckServices"]),
        .library(name: "SkillDeckTelemetry", targets: ["SkillDeckTelemetry"])
    ],
    dependencies: [
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", from: "8.0.0"),
        .package(url: "https://github.com/amplitude/Amplitude-Swift", from: "1.0.0")
    ],
    targets: [
        .target(name: "SkillDeckCore"),
        .target(
            name: "SkillDeckSources",
            dependencies: ["SkillDeckCore"]
        ),
        .target(
            name: "SkillDeckAgents",
            dependencies: ["SkillDeckCore"]
        ),
        .target(
            name: "SkillDeckPersistence",
            dependencies: ["SkillDeckCore"]
        ),
        .target(
            name: "SkillDeckServices",
            dependencies: [
                "SkillDeckCore",
                "SkillDeckSources",
                "SkillDeckAgents",
                "SkillDeckPersistence"
            ]
        ),
        .target(
            name: "SkillDeckTelemetry",
            dependencies: [
                "SkillDeckCore",
                .product(name: "Sentry", package: "sentry-cocoa"),
                .product(name: "AmplitudeSwift", package: "Amplitude-Swift")
            ]
        ),
        .testTarget(
            name: "SkillDeckCoreTests",
            dependencies: ["SkillDeckCore"]
        ),
        .testTarget(
            name: "SkillDeckSourcesTests",
            dependencies: ["SkillDeckSources"]
        ),
        .testTarget(
            name: "SkillDeckAgentsTests",
            dependencies: ["SkillDeckAgents"]
        ),
        .testTarget(
            name: "SkillDeckPersistenceTests",
            dependencies: ["SkillDeckPersistence"]
        ),
        .testTarget(
            name: "SkillDeckServicesTests",
            dependencies: ["SkillDeckServices"]
        ),
        .testTarget(
            name: "SkillDeckTelemetryTests",
            dependencies: ["SkillDeckTelemetry"]
        )
    ]
)
