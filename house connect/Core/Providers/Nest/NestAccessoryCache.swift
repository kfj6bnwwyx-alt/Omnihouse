//
//  NestAccessoryCache.swift
//  house connect
//
//  Persists Nest accessories, rooms, and homes to disk so they survive
//  app restarts when the provider can't connect. Structural clone of
//  SmartThingsAccessoryCache — same Application Support pattern, atomic
//  writes, graceful decode failure.
//

import Foundation

struct NestCacheSnapshot: Codable {
    var homes: [Home]
    var rooms: [Room]
    var accessories: [Accessory]
}

final class NestAccessoryCache: Sendable {
    private let fileURL: URL

    nonisolated init(fileURL: URL? = nil) {
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
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
            self.fileURL = appDir.appendingPathComponent("nest-cache.json")
        }
    }

    func load() -> NestCacheSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(NestCacheSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    func save(_ snapshot: NestCacheSnapshot) {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            // Non-fatal — works without persistence.
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
