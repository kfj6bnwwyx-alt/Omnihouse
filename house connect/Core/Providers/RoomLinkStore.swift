//
//  RoomLinkStore.swift
//  house connect
//
//  Persists user-created room links — pairs of (provider, roomID)
//  tuples that should be treated as the same physical room even
//  though they appear as separate entries across providers (e.g.
//  HomeKit "Family Room" + HA area "family_room").
//
//  Parallels DeviceLinkStore in shape and persistence: JSON in
//  UserDefaults, idempotent add, defensive dedup on load, and a
//  "clear all" escape hatch.
//
//  RoomMerging.merge() consumes `links` to fold secondaries into
//  their primary's bucket. Views render the primary's name and
//  the unioned device list.
//

import Foundation
import Observation

// MARK: - Key

/// Composite identifier for a room across providers. `Room.id` is
/// only unique within a provider, so stored links and merge-bucket
/// keys need to carry the provider alongside it.
struct RoomKey: Codable, Hashable, Sendable {
    let provider: ProviderID
    let roomID: String

    nonisolated init(provider: ProviderID, roomID: String) {
        self.provider = provider
        self.roomID = roomID
    }

    nonisolated init(_ room: Room) {
        self.provider = room.provider
        self.roomID = room.id
    }
}

// MARK: - Link model

struct ManualRoomLink: Codable, Identifiable, Hashable {
    let id: UUID
    /// The canonical side — the room shown as the merged name.
    let primary: RoomKey
    /// The alias — folded into the primary's bucket.
    let secondary: RoomKey
    var createdAt: Date

    init(primary: RoomKey, secondary: RoomKey) {
        self.id = UUID()
        self.primary = primary
        self.secondary = secondary
        self.createdAt = Date()
    }
}

// MARK: - Store

@MainActor
@Observable
final class RoomLinkStore {
    private(set) var links: [ManualRoomLink] = []

    private static let udKey = "roomLinks.v1"

    init() {
        load()
    }

    // MARK: - Queries

    /// Every RoomKey that participates in any link, either side.
    func linkedKeys() -> Set<RoomKey> {
        var result: Set<RoomKey> = []
        for link in links {
            result.insert(link.primary)
            result.insert(link.secondary)
        }
        return result
    }

    /// True if `a` and `b` are linked (in either direction).
    func areLinked(_ a: RoomKey, _ b: RoomKey) -> Bool {
        links.contains {
            ($0.primary == a && $0.secondary == b)
                || ($0.primary == b && $0.secondary == a)
        }
    }

    /// If `key` is a secondary in some link, return its primary. If
    /// `key` is a primary (or unlinked), return `key` unchanged.
    func canonicalKey(for key: RoomKey) -> RoomKey {
        if let link = links.first(where: { $0.secondary == key }) {
            return link.primary
        }
        return key
    }

    /// All secondaries whose primary equals `key`.
    func secondaries(for key: RoomKey) -> [RoomKey] {
        links.filter { $0.primary == key }.map(\.secondary)
    }

    // MARK: - Mutations

    @discardableResult
    func addLink(primary: RoomKey, secondary: RoomKey) -> ManualRoomLink? {
        guard primary != secondary else { return nil }
        // Idempotent: same pair in either direction.
        if let existing = links.first(where: {
            ($0.primary == primary && $0.secondary == secondary)
                || ($0.primary == secondary && $0.secondary == primary)
        }) {
            return existing
        }
        let link = ManualRoomLink(primary: primary, secondary: secondary)
        links.append(link)
        save()
        return link
    }

    func removeLink(id: UUID) {
        links.removeAll { $0.id == id }
        save()
    }

    func removeLinks(involving key: RoomKey) {
        links.removeAll { $0.primary == key || $0.secondary == key }
        save()
    }

    func removeAllLinks() {
        links.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.udKey),
              let decoded = try? JSONDecoder().decode([ManualRoomLink].self, from: data)
        else { return }
        // Dedupe (A,B) ↔ (B,A) defensively.
        var seen = Set<Set<RoomKey>>()
        var uniq: [ManualRoomLink] = []
        for link in decoded {
            let key: Set<RoomKey> = [link.primary, link.secondary]
            if seen.insert(key).inserted {
                uniq.append(link)
            }
        }
        links = uniq
        if uniq.count != decoded.count { save() }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(links) else { return }
        UserDefaults.standard.set(data, forKey: Self.udKey)
    }
}
