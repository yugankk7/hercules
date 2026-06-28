// swift-tools-version: 6.2
import PackageDescription

// Modular package structure (HERC-003), mirroring NOOP:
//   PolarProtocol — API models + clients + Keychain (no UI, no DB)
//   PolarStore    — GRDB-backed local store (depends on PolarProtocol)
//   HerculesUI    — design system + screens (depends on PolarProtocol)
// The app target depends on all three.
let package = Package(
    name: "HerculesPackages",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "PolarProtocol", targets: ["PolarProtocol"]),
        .library(name: "PolarStore", targets: ["PolarStore"]),
        .library(name: "HerculesUI", targets: ["HerculesUI"]),
    ],
    dependencies: [
        // HERC-002: GRDB via SPM (hold polar-ble-sdk until phase 2).
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "PolarProtocol"
        ),
        .target(
            name: "PolarStore",
            dependencies: [
                "PolarProtocol",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .target(
            name: "HerculesUI",
            dependencies: ["PolarProtocol"]
        ),
        // HERC-040/041/042 acceptance tests: schema, idempotency, round-trip.
        .testTarget(
            name: "PolarStoreTests",
            dependencies: ["PolarStore", "PolarProtocol"]
        ),
    ]
)
