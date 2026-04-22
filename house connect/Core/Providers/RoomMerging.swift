//
//  RoomMerging.swift
//  house connect
//
//  Folds cross-provider `Room`s that the user has manually linked
//  into unified `MergedRoom` buckets. Unlinked rooms survive as
//  single-member buckets so the dashboard grid still renders them.
//
//  Name-based auto-merging is intentionally *not* part of this
//  module: the old `T3HomeDashboardView` and `T3RoomsTabView`
//  dedupe-by-lowercased-name collapsed any two rooms with the
//  same typed name regardless of whether they're the same
//  physical space. Links are user-driven and explicit.
//

import Foundation

/// Unified room bucket — one MergedRoom per physical space, built
/// from one primary Room plus zero or more linked secondaries.
struct MergedRoom: Identifiable, Hashable {
    /// Primary's RoomKey serialized to a string. Stable across
    /// merges so SwiftUI `ForEach(id:)` stays on the same view.
    let id: String
    /// Display name — always the primary's name.
    let name: String
    /// The primary room (canonical side of any link).
    let primary: Room
    /// All secondary rooms folded into this bucket.
    let secondaries: [Room]
    /// Every provider contributing a room to this bucket, primary first.
    let providers: [ProviderID]

    /// Primary + all secondaries.
    var allRooms: [Room] { [primary] + secondaries }

    /// All (provider, roomID) pairs contained in this bucket. Used
    /// by views to filter accessories across every linked room.
    var allKeys: [RoomKey] { allRooms.map(RoomKey.init) }

    /// True when this bucket contains more than one room (at least
    /// one link has been applied). Lets the UI render a small
    /// "merged" badge without re-deriving the flag.
    var isMerged: Bool { !secondaries.isEmpty }
}

enum RoomMerging {
    /// Fold `rooms` through `links` and return a stable, ordered
    /// `[MergedRoom]`. Order: primaries in the same order the
    /// inputs arrived, followed by any unlinked rooms in arrival
    /// order. Secondaries never appear at the top level — they're
    /// always inside their primary's bucket.
    static func merge(rooms: [Room], links: [ManualRoomLink]) -> [MergedRoom] {
        // Fast path: no links → one bucket per room.
        guard !links.isEmpty else {
            return rooms.map { single($0) }
        }

        let linkStore = LinkIndex(links: links)
        var byPrimaryKey: [RoomKey: (primary: Room?, secondaries: [Room])] = [:]
        var order: [RoomKey] = [] // primary keys, in first-seen order

        for room in rooms {
            let key = RoomKey(room)
            let canonical = linkStore.canonical(for: key)

            if byPrimaryKey[canonical] == nil {
                byPrimaryKey[canonical] = (primary: nil, secondaries: [])
                order.append(canonical)
            }

            if canonical == key {
                // This room IS the primary (or unlinked).
                byPrimaryKey[canonical]?.primary = room
            } else {
                // This room is a secondary — attach to its primary.
                byPrimaryKey[canonical]?.secondaries.append(room)
            }
        }

        var result: [MergedRoom] = []
        for canonical in order {
            guard let bucket = byPrimaryKey[canonical] else { continue }
            if let primary = bucket.primary {
                let providers = [primary.provider] +
                    bucket.secondaries.map(\.provider).filter { $0 != primary.provider }
                result.append(MergedRoom(
                    id: keyID(canonical),
                    name: primary.name,
                    primary: primary,
                    secondaries: bucket.secondaries,
                    providers: Array(NSOrderedSet(array: providers)) as? [ProviderID] ?? providers
                ))
            } else if let firstSecondary = bucket.secondaries.first {
                // Primary is missing from `rooms` (provider not
                // reporting it right now) — promote a secondary so
                // the user still sees the room. This can happen
                // when HomeKit is temporarily unreachable but HA is
                // live; we don't want the bucket to disappear.
                let rest = Array(bucket.secondaries.dropFirst())
                result.append(MergedRoom(
                    id: keyID(canonical),
                    name: firstSecondary.name,
                    primary: firstSecondary,
                    secondaries: rest,
                    providers: [firstSecondary.provider] + rest.map(\.provider)
                ))
            }
        }
        return result
    }

    private static func single(_ room: Room) -> MergedRoom {
        MergedRoom(
            id: keyID(RoomKey(room)),
            name: room.name,
            primary: room,
            secondaries: [],
            providers: [room.provider]
        )
    }

    /// Stable string form of a RoomKey, used as `MergedRoom.id`.
    private static func keyID(_ key: RoomKey) -> String {
        "\(key.provider.rawValue)|\(key.roomID)"
    }
}

// MARK: - Private

/// Precomputes primary lookups so `merge()` runs in O(rooms + links)
/// rather than O(rooms × links).
private struct LinkIndex {
    private let secondaryToPrimary: [RoomKey: RoomKey]

    init(links: [ManualRoomLink]) {
        var map: [RoomKey: RoomKey] = [:]
        for link in links {
            map[link.secondary] = link.primary
        }
        self.secondaryToPrimary = map
    }

    /// If `key` is a secondary, return its primary. Otherwise `key`.
    func canonical(for key: RoomKey) -> RoomKey {
        secondaryToPrimary[key] ?? key
    }
}
