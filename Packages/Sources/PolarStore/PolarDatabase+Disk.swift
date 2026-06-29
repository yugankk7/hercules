import Foundation

/// On-disk provisioning for the **one** shared store the app opens at launch.
/// Split from `PolarDatabase.swift` so the path/location policy (A1/A2 of
/// `PRE-EPIC-5-store-readiness.md`) lives in one obvious place.
extension PolarDatabase {

    /// Default on-disk filename under Application Support.
    public static let defaultFilename = "hercules.sqlite"

    /// Open (creating if needed) the single persistent store at
    /// `Application Support/<filename>`, migrating to the current schema.
    ///
    /// **Application Support** is the correct home: unlike `Documents` it is not
    /// user-visible or iCloud-backed, and unlike `Caches`/`tmp` it is **not
    /// purgeable** — iOS won't delete it under storage pressure, so a sync's data
    /// survives restarts. The directory is excluded from iCloud backup of user
    /// documents by being outside `Documents`; the file is reconstructible from
    /// the API, so no extra backup-exclusion flag is set.
    ///
    /// Open this **once** at the composition root and share the instance: the
    /// underlying `DatabasePool` (WAL) serves concurrent UI reads during a sync
    /// write, but two pools on the same path would not (Safeguard / A1).
    public static func onDisk(
        filename: String = defaultFilename,
        fileManager: FileManager = .default
    ) throws -> PolarDatabase {
        let dir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        // `create: true` above creates the domain root; ensure the leaf exists too
        // (Application Support is not guaranteed present on a fresh install).
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return try PolarDatabase(path: dir.appendingPathComponent(filename))
    }
}
