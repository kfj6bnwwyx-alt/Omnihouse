//
//  SmartThingsAccessoryCache.swift
//  house connect
//
//  Persists SmartThings accessories, rooms, and homes to disk so they
//  survive app restarts when the provider can't connect (missing token,
//  expired token, network down). Follows the same SceneStore pattern:
//  JSON in Application Support, atomic writes, graceful decode failure.
//
//  The cache is the ONLY reason SmartThings devices can remain visible
//  as "Disconnected" instead of vanishing when auth fails. Without it,
//  the in-memory accessory list clears on every cold start without a
//  valid token.
//

import Foundation

/// Everything we persist for SmartThings offline display.
struct SmartThingsCacheSnapshot: Codable {
    var homes: [Home]
    var rooms: [Room]
    var accessories: [Accessory]
}

/// Disk-backed cache for SmartThings accessory state. Thread-safe by
/// virtue of being called only from `@MainActor` SmartThingsProvider.
final class SmartThingsAccessoryCache {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let fm = FileManager.default
            let base = (try? fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true))
                ?? fm.temporaryDirectory
            let appDir = base.appendingPathComponent("house connect", isDirectory: true)
            try? fm.createDirectory(at: appDir,
                                    withIntermediateDirectories: true)
            self.fileURL = appDir.appendingPathComponent("smartthings-cache.json")
        }
    }

    /// Returns the last-known-good snapshot, or nil if no cache exists
    /// or if the file is corrupt / from an incompatible schema version.
    func load() -> SmartThingsCacheSnapshot? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(SmartThingsCacheSnapshot.self, from: data)
        } catch {
            // Corrupt or schema-incompatible — treat as "no cache". The
            // user just won't see stale devices until they reconnect,
            // which is the pre-cache behavior anyway.
            return nil
        }
    }

    /// Atomically writes the current SmartThings state to disk. Called
    /// after every successful refresh so the cache tracks reality.
    func save(_ snapshot: SmartThingsCacheSnapshot) {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Non-fatal. The app works fine without persistence — the
            // user just loses their "disconnected devices" view on next
            // cold start if the save keeps failing. Not worth crashing.
        }
    }

    /// Removes the cache file entirely. Called when the user explicitly
    /// disconnects SmartThings (as opposed to token expiry) so devices
    /// truly vanish — intentional disconnect should not leave ghosts.
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
